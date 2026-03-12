use ecow::eco_format;
use typst_syntax::Spanned;

use crate::diag::{At, LoadError, LoadedWithin, ReportPos, SourceResult};
use crate::engine::Engine;
use crate::foundations::{Array, Datetime, Dict, IntoValue, Str, Value, func, scope};
use crate::loading::{DataSource, Load, Readable};

/// Reads structured data from a TOML file.
///
/// The file must contain a valid TOML table. The TOML values will be converted
/// into corresponding Typst values as listed in the [table below](#conversion).
///
/// The function returns a dictionary representing the TOML table.
///
/// The TOML file in the example consists of a table with the keys `title`,
/// `version`, and `authors`.
///
/// # Example
/// ```example
/// #let details = toml("details.toml")
///
/// Title: #details.title \
/// Version: #details.version \
/// Authors: #(details.authors
///   .join(", ", last: " and "))
/// ```
///
/// # Conversion details { #conversion }
///
/// First of all, TOML documents are tables. Other values must be put in a table
/// to be encoded or decoded.
///
/// | TOML value | Converted into Typst |
/// | ---------- | -------------------- |
/// | string     | [`str`]              |
/// | integer    | [`int`]              |
/// | float      | [`float`]            |
/// | boolean    | [`bool`]             |
/// | datetime   | [`datetime`]         |
/// | array      | [`array`]            |
/// | table      | [`dictionary`]       |
///
/// | Typst value                           | Converted into TOML            |
/// | ------------------------------------- | ------------------------------ |
/// | types that can be converted from TOML | corresponding TOML value       |
/// | `{none}`                              | ignored                        |
/// | [`bytes`]                             | string via [`repr`]            |
/// | [`symbol`]                            | string                         |
/// | [`content`]                           | a table describing the content |
/// | other types ([`length`], etc.)        | string via [`repr`]            |
///
/// ## Notes
/// - Be aware that TOML integers larger than 2<sup>63</sup>-1 or smaller
///   than -2<sup>63</sup> cannot be represented losslessly in Typst, and an
///   error will be thrown according to the
///   [specification](https://toml.io/en/v1.0.0#integer).
///
/// - Bytes are not encoded as TOML arrays for performance and readability
///   reasons. Consider using [`cbor.encode`] for binary data.
///
/// - The `repr` function is [for debugging purposes only]($repr/#debugging-only),
///   and its output is not guaranteed to be stable across Typst versions.
#[func(scope, title = "TOML")]
pub fn toml(
    engine: &mut Engine,
    /// A path to a TOML file or raw TOML bytes.
    source: Spanned<DataSource>,
) -> SourceResult<Dict> {
    let loaded = source.load(engine.world)?;
    let raw = loaded.data.as_str().within(&loaded)?;
    let value: ::toml::Value =
        ::toml::from_str(raw).map_err(format_toml_error).within(&loaded)?;
    toml_value_to_dict(value)
        .map_err(|msg| LoadError::new(ReportPos::None, "failed to parse TOML", msg))
        .within(&loaded)
}

#[scope]
impl toml {
    /// Reads structured data from a TOML string/bytes.
    #[func(title = "Decode TOML")]
    #[deprecated(
        message = "`toml.decode` is deprecated, directly pass bytes to `toml` instead",
        until = "0.15.0"
    )]
    pub fn decode(
        engine: &mut Engine,
        /// TOML data.
        data: Spanned<Readable>,
    ) -> SourceResult<Dict> {
        toml(engine, data.map(Readable::into_source))
    }

    /// Encodes structured data into a TOML string.
    #[func(title = "Encode TOML")]
    pub fn encode(
        /// Value to be encoded.
        ///
        /// TOML documents are tables. Therefore, only dictionaries are suitable.
        value: Spanned<Dict>,
        /// Whether to pretty-print the resulting TOML.
        #[named]
        #[default(true)]
        pretty: bool,
    ) -> SourceResult<Str> {
        let Spanned { v: value, span } = value;
        if pretty { ::toml::to_string_pretty(&value) } else { ::toml::to_string(&value) }
            .map(|v| v.into())
            .map_err(|err| eco_format!("failed to encode value as TOML ({err})"))
            .at(span)
    }
}

/// Format the user-facing TOML error message.
fn format_toml_error(error: ::toml::de::Error) -> LoadError {
    let pos = error.span().map(ReportPos::from).unwrap_or_default();
    let msg = error.message();
    // Map implementation-specific integer overflow messages to user-friendly ones
    // that match the TOML spec language for out-of-range integers.
    let msg: &str = if msg == "u64 value was too large" {
        "number too large to fit in target type"
    } else if msg.starts_with("invalid type: integer") && msg.contains("as i128") {
        "number too small to fit in target type"
    } else {
        msg
    };
    LoadError::new(pos, "failed to parse TOML", msg)
}

/// Convert a parsed TOML table into a Typst dictionary.
///
/// By parsing to [`::toml::Value`] first (rather than deserializing directly
/// into a [`Dict`]), integers that do not fit in [`i64`] are correctly
/// rejected with an error instead of being silently converted to floats.
fn toml_value_to_dict(value: ::toml::Value) -> Result<Dict, &'static str> {
    match value {
        ::toml::Value::Table(table) => Ok(table
            .into_iter()
            .map(|(k, v)| (Str::from(k), toml_value_to_typst(v)))
            .collect()),
        _ => Err("expected a TOML table at the top level"),
    }
}

/// Convert a [`::toml::Value`] into a Typst [`Value`].
fn toml_value_to_typst(value: ::toml::Value) -> Value {
    match value {
        ::toml::Value::String(s) => s.into_value(),
        ::toml::Value::Integer(i) => i.into_value(),
        ::toml::Value::Float(f) => f.into_value(),
        ::toml::Value::Boolean(b) => b.into_value(),
        ::toml::Value::Datetime(dt) => toml_datetime_to_typst(dt),
        ::toml::Value::Array(arr) => {
            arr.into_iter()
                .map(toml_value_to_typst)
                .collect::<Array>()
                .into_value()
        }
        ::toml::Value::Table(table) => table
            .into_iter()
            .map(|(k, v)| (Str::from(k), toml_value_to_typst(v)))
            .collect::<Dict>()
            .into_value(),
    }
}

/// Convert a [`toml_datetime::Datetime`] into a Typst [`Value`].
///
/// Falls back to a string representation when the datetime cannot be
/// represented as a Typst [`Datetime`].
fn toml_datetime_to_typst(dt: ::toml::value::Datetime) -> Value {
    let converted = match (dt.date, dt.time) {
        (Some(date), Some(time)) => Datetime::from_ymd_hms(
            date.year as i32,
            date.month,
            date.day,
            time.hour,
            time.minute,
            time.second.unwrap_or(0),
        ),
        (Some(date), None) => Datetime::from_ymd(date.year as i32, date.month, date.day),
        (None, Some(time)) => {
            Datetime::from_hms(time.hour, time.minute, time.second.unwrap_or(0))
        }
        (None, None) => None,
    };
    match converted {
        Some(datetime) => datetime.into_value(),
        None => dt.to_string().into_value(),
    }
}
