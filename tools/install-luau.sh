#!/usr/bin/env bash
# Official Luau release with pinned SHA-256.
set -euo pipefail
LU_VERSION=0.744
LU_SHA=6506f0852c623aaffcb28494aac16c26dc04a269ea0e16cc0aafc8c8ac79f3ec
INSTALL_DIR="$(mktemp -d)"
ARCHIVE="$INSTALL_DIR/luau-ubuntu.zip"
curl --fail --location --silent --show-error --retry 3 \
  "https://github.com/luau-lang/luau/releases/download/$LU_VERSION/luau-ubuntu.zip" -o "$ARCHIVE"
printf '%s  %s\n' "$LU_SHA" "$ARCHIVE" | sha256sum --check
unzip -q -o "$ARCHIVE" -d "$INSTALL_DIR"
COMPILER="$(find "$INSTALL_DIR" -type f -name luau-compile -print -quit)"
if [[ -z "$COMPILER" ]]; then
  echo "::error::Missing luau-compile binary in official package" >&2
  exit 1
fi
chmod +x "$COMPILER"
for bin in luau luau-analyze; do
  if [[ -f "$(dirname "$COMPILER")/$bin" ]]; then chmod +x "$(dirname "$COMPILER")/$bin"; fi
done
"$COMPILER" --help >/dev/null
BIN_DIR="$(dirname "$COMPILER")"
if [[ -v GITHUB_PATH ]]; then
  echo "$BIN_DIR" >> "$GITHUB_PATH"
fi
echo "Official Luau $LU_VERSION installed; SHA-256 verified"
