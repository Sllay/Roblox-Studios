#!/usr/bin/env bash
set -euo pipefail
VERSION=1.70.1
SHA=1a2ea1ae4f98f8946cefd970a4b54853e11ab4775e6932faa7f60cf920346567
DIR="$(mktemp -d)"
curl --fail --location --silent --show-error --retry 3 "https://github.com/JohnnyMorganz/luau-lsp/releases/download/$VERSION/luau-lsp-linux-x86_64.zip" -o "$DIR/lsp.zip"
printf '%s  %s\n' "$SHA" "$DIR/lsp.zip" | sha256sum --check
unzip -q "$DIR/lsp.zip" -d "$DIR"
BIN="$(find "$DIR" -type f -name luau-lsp -print -quit)"
test -n "$BIN"
chmod +x "$BIN"
curl --fail --location --silent --show-error --retry 3 "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$VERSION/scripts/globalTypes.None.d.luau" -o "$DIR/globalTypes.d.luau"
test "$(git hash-object "$DIR/globalTypes.d.luau")" = "674fd4f5d95eaf5d0061ab403b1648c6fd341b80"
echo "$(dirname "$BIN")" >> "$GITHUB_PATH"
echo "RS_ROBLOX_DEFINITIONS=$DIR/globalTypes.d.luau" >> "$GITHUB_ENV"
