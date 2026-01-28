#!/usr/bin/env bash
set -euxo pipefail

# 1. Install tools

curl -sS https://webi.sh/sd | sh && source ~/.config/envman/PATH.env
curl https://mise.run | sh

# 2. Clone typst-docs-web

# Tested against https://github.com/typst-community/typst-docs-web/commit/5367578e2aa099d3958fc075dc8d9060282930b6
git clone --depth 1 https://github.com/typst-community/typst-docs-web docs-web

# 3. Prepare files

cat << EOF >> .gitignore
# Generated
/assets/
/docs.json
EOF

# The rust edition has been bumped to 2024 in https://github.com/typst/typst/pull/6637, use the system default instead
sd --fixed-strings \
    'rust = "1.83.0"' \
    '' \
    docs-web/mise.toml

cat << EOF > docs-web/public/metadata.json
{
  "\$schema": "../metadata.schema.json",
  "language": "en-US",
  "version": "0.dev.$(git log -1 --format=%cs)",
  "typstOfficialUrl": "https://typst.app",
  "typstOfficialDocsUrl": "https://typst.app/docs/",
  "githubOrganizationUrl": "https://github.com/typst-community",
  "socialLinks": [
    { "url": "https://github.com/typst-community/typst-docs-web" },
    {
      "title": "Discord (Typst)",
      "url": "https://discord.gg/2uDybryKPe"
    }
  ],
  "originUrl": "https://ydx-typst.netlify.app/",
  "basePath": "/",
  "displayTranslationStatus": false
}
EOF

curl -L https://github.com/typst-community/org/raw/main/design/typst-community.icon.png \
  -o docs-web/public/favicon.png

# 4. Build

rustup default stable
cargo run --package typst-docs -- --assets-dir assets --out-file docs.json --base /

cd docs-web
ln -s ../../docs.json public/docs.json
ln -s ../../assets public/assets

mise trust
mise install
mise exec -- bun install
mise exec -- bun run build
