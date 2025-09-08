#!/usr/bin/env bash
set -euxo pipefail

# 1. Install tools

curl -sS https://webi.sh/sd | sh && source ~/.config/envman/PATH.env
curl https://mise.run | sh

# 2. Clone typst-jp/docs

# Tested against https://github.com/typst-jp/docs/commit/e3e97eb0b296b31dd93e4761f3a8cc35719a3144
git clone --depth 1 --no-checkout --filter=tree:0 https://github.com/typst-jp/docs ../jp
cd ../jp
git sparse-checkout init
git sparse-checkout set website/ tsconfig.json package.json bun.lockb mise.toml
git switch main
cd -

# 3. Move files from typst-jp/docs

cat << EOF >> .gitignore
# From typst-jp/docs
/website/
/tsconfig.json
/package.json
/bun.lockb
/mise.toml

# Generated
/assets/
/docs.json
EOF

# This `cp -r` cannot be replaced with `ln -s`, because there will be a symlink created in website/public
cp -r ../jp/website/ .
ln -s ../jp/{tsconfig.json,package.json,bun.lockb} .
cp ../jp/mise.toml .

# The rust edition has been bumped to 2024 in https://github.com/typst/typst/pull/6637
sd --fixed-strings \
    'rust = "1.83.0"' \
    'rust = "1.89.0"' \
    mise.toml

# Change the base
sd --fixed-strings \
    '"basePath": "/docs/"' \
    '"basePath": "/"' \
    website/metadata.json

# Switch to English
sd --fixed-strings \
    '"language": "ja-JP"' \
    '"language": "en-US"' \
    website/metadata.json

# Disable translation
sd --fixed-strings \
    '"displayTranslationStatus": true' \
    '"displayTranslationStatus": false' \
    website/metadata.json

# Replace the typst version with the commit date
sd --fixed-strings \
    '"version": "0.13.1"' \
    "\"version\": \"0.dev.$(git log -1 --format=%cs)\"" \
    website/metadata.json

# 4. Build

mise trust
mise install
mise run generate

# For dev: Run `mise run dev`
# For deploy: Upload website/dist
