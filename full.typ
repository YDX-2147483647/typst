#set page(height: auto)
#set text(lang: "zh", region: "CN", font: "Noto Serif CJK is fantastic, but spaces are more visible between tofu")

#show raw: set text(lang: "zh", region: "CN", font: "Noto Serif CJK is fantastic, but spaces are more visible between tofu")
#show raw: it => [*Expected*] + it

// https://github.com/typst/typst/issues/792#issuecomment-2351027959
= Words

汉字 分词
技术 English Latin
Continue 汉字 
And
孔乙己

```
汉字 分词技术 English Latin Continue 汉字 And 孔乙己
```

= Sentences

鲁镇的酒店的格局，是和别处不同的：
都是当街一个曲尺形的大柜台，
柜里面预备着热水，可以随时温酒。

鲁镇的酒店的格局，是和别处不同的： //
都是当街一个曲尺形的大柜台， //
柜里面预备着热水，可以随时温酒。

```
鲁镇的酒店的格局，是和别处不同的：都是当街一个曲尺形的大柜台，柜里面预备着热水，可以随时温酒。
鲁镇的酒店的格局，是和别处不同的： 都是当街一个曲尺形的大柜台， 柜里面预备着热水，可以随时温酒。
```

// https://github.com/typst/typst/issues/792#issuecomment-2381344894
= Str

- #"数学 语文 物理"
- 数学 语文 物理

```
数学 语文 物理
数学语文物理
```

// https://github.com/typst/typst/issues/792#issuecomment-2381940136
= Edge cases

== Case 1 — space is *not* desired here
中文
#footnote[分词]

== Case 2 — space is *not* desired here
*中文*
分词

== Case 3 — space is *not* desired here
#let a = [中文]
#let b = [分词]
#a
#b

== Case 4 — space is desired here
关于
#box[TeX]

== Case 5 — space is desired here, but we can safely strip it because it will be added back during layout
关于
Typst

// https://github.com/typst/typst/issues/792#issuecomment-2613955954
= Assert

/// Ensures that all arguments are equal.
#let all-eq(..args) = {
  if args.pos().len() == 0 { return }

  let (first, ..rest) = args.pos()
  for r in rest { assert.eq(first, r) }
  all-eq(..rest)
}

#let latin = "fruit"
#let han = "水果"

#for space in (auto, none) {
    set text(cjk-latin-spacing: space)

    all-eq(
    [#latin
        #latin],
    [#latin #latin],
    [#latin    #latin],
    [fruit] + [ ] + [fruit],
    )

    all-eq(
    [#han
        #han],
    [#han #han],
    [#han    #han],
    [水果] + [ ] + [水果],
    )

    all-eq(
    [#han
        #latin],
    [#han #latin],
    [#han    #latin],
    [水果] + [ ] + [fruit],
    )

    all-eq(
    [#han] + [#latin],
    [#han#latin],
    [水果] + [fruit]
  )
}
