#!/usr/bin/env bash
set -euxo pipefail

# 1. Install tools

curl -sS https://webi.sh/sd | sh && source ~/.config/envman/PATH.env
curl https://mise.run | sh

# 2. Clone typst-jp/docs

# Tested against https://github.com/typst-jp/docs/commit/529c33dec006b20729795ca64e3079e18ae4e1d9
git clone --depth 1 --no-checkout --filter=tree:0 https://github.com/typst-jp/docs ../jp
cd ../jp
git sparse-checkout init
git sparse-checkout set website/ tsconfig.json package.json bun.lockb .mise.toml
git switch main
cd -

# 3. Move files from typst-jp/docs

cat << EOF >> .gitignore
# From typst-jp/docs
/website/
/tsconfig.json
/package.json
/bun.lockb
/.mise.toml

# Generated
/assets/
/docs.json
EOF

# This `cp -r` cannot be replaced with `ln -s`, because there will be a symlink created in website/public
cp -r ../jp/website/ .
ln -s ../jp/{tsconfig.json,package.json,bun.lockb} .
cp ../jp/.mise.toml .

# The rust edition has been bumped to 2024 in https://github.com/typst/typst/pull/6637
sd --fixed-strings \
    'rust = "1.83.0"' \
    'rust = "1.89.0"' \
    .mise.toml

# Change the base
sd --fixed-strings \
    'run = "cargo run --package typst-docs -- --assets-dir assets --out-file docs.json --base /docs/"' \
    'run = "cargo run --package typst-docs -- --assets-dir assets --out-file docs.json --base /"' \
    .mise.toml
sd --fixed-strings \
    'export const basePath: "/" | `/${string}/` = "/docs/";' \
    'export const basePath: "/" | `/${string}/` = "/";' \
    website/src/metadata.ts

# Switch to English
sd --fixed-strings \
    'export { translation, Translation } from "./ja-JP";' \
    'export { translation, Translation } from "./en-US";' \
    website/src/translation/index.tsx

# Replace the typst version with the commit hash
sd --fixed-strings \
    '"version": "0.13.1"' \
    "\"version\": \"dev.$(git log -1 --format=%cs)\"" \
    website/package.json

# 4. Build

mise trust
mise install
mise run generate

# For dev: Run `mise run dev`
# For deploy: Upload website/dist
