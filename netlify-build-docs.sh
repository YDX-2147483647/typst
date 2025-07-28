#!/usr/bin/env bash
set -euxo pipefail

# 1. Install tools

curl -sS https://webi.sh/sd | sh && source ~/.config/envman/PATH.env
curl https://mise.run | sh

# 2. Clone typst-jp.github.io

# Tested against https://github.com/typst-jp/typst-jp.github.io/commit/f588f0d53dbb39225739fa7faeecb33d9b4b055b
git clone --depth 1 --no-checkout --filter=tree:0 https://github.com/typst-jp/typst-jp.github.io ../jp
cd ../jp
git sparse-checkout init
git sparse-checkout set website/ tsconfig.json package.json bun.lockb .mise.toml
git switch main
cd -

# 3. Move files from typst-jp

cat << EOF >> .gitignore
# From typst-jp
/website/
/tsconfig.json
/package.json
/bun.lockb
/.mise.toml

# Generated
/assets/docs/
/assets/docs.json
EOF

# This `cp -r` cannot be replaced with `ln -s`, because there will be a symlink created in website/public
cp -r ../jp/website/ .
ln -s ../jp/{tsconfig.json,package.json,bun.lockb} .
cp ../jp/.mise.toml .

# The rust edition has been bumped to 2024 in https://github.com/typst/typst/pull/6637
sd --fixed-strings \
    'rust = "1.83.0"' \
    'rust = "1.88.0"' \
    .mise.toml

# Use canonical typst-docs for `mise run generate-docs`
sd --fixed-strings \
    'run = "cargo test --package typst-docs --lib -- tests::test_docs --exact --nocapture"' \
    'run = "cargo run --package typst-docs -- --assets-dir assets/docs --out-file assets/docs.json --base /docs/"' \
    .mise.toml
mkdir -p website/public/docs
sd --fixed-strings \
    'const publicAssetsDocsPath = resolve(__dirname, "./public/assets/docs/");' \
    'const publicAssetsDocsPath = resolve(__dirname, "./public/docs/assets/");' \
    website/vite.config.ts

# 4. Build

mise trust
mise install
mise run generate

# For debugging:
cp assets/docs.json website/dist/

# For dev: Run `mise run dev`
# For deploy: Upload website/dist
