#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SOURCE="$SCRIPT_DIR/plugin/deeppipe-mobile"
DIST_DIR="$SCRIPT_DIR/dist"
VERSION="$(awk -F= '$1 == "version" { print $2; exit }' "$PLUGIN_SOURCE/metadata.txt" | tr -d '[:space:]')"
if [[ -z "$VERSION" ]]; then
  echo "Could not read plugin version from metadata.txt" >&2
  exit 1
fi
PLUGIN_ZIP="$DIST_DIR/deeppipe-mobile-v${VERSION}.zip"
BUNDLE_ZIP="$DIST_DIR/DeepPipe_QField_API_Test_v${VERSION}.zip"

mkdir -p "$DIST_DIR"
rm -f "$PLUGIN_ZIP" "$BUNDLE_ZIP"

(
  cd "$PLUGIN_SOURCE"
  zip -q -r "$PLUGIN_ZIP" . -x "*.DS_Store" "__MACOSX/*"
)

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT
mkdir -p "$STAGING_DIR/plugin" "$STAGING_DIR/plugin-install" "$STAGING_DIR/tests"
cp "$SCRIPT_DIR/README.md" "$STAGING_DIR/README.md"
cp -R "$SCRIPT_DIR/docs" "$STAGING_DIR/docs"
cp -R "$SCRIPT_DIR/project-template" "$STAGING_DIR/project-template"
cp -R "$PLUGIN_SOURCE" "$STAGING_DIR/plugin/deeppipe-mobile"
cp "$PLUGIN_ZIP" "$STAGING_DIR/plugin-install/deeppipe-mobile-v${VERSION}.zip"
cp "$SCRIPT_DIR/tests/test_logic.mjs" "$STAGING_DIR/tests/test_logic.mjs"
cp "$SCRIPT_DIR/tests/validate_source.mjs" "$STAGING_DIR/tests/validate_source.mjs"
cp "$SCRIPT_DIR/tests/test_api_contract.mjs" "$STAGING_DIR/tests/test_api_contract.mjs"

(
  cd "$STAGING_DIR"
  zip -q -r "$BUNDLE_ZIP" . -x "*.DS_Store" "__MACOSX/*"
)

unzip -tq "$PLUGIN_ZIP" >/dev/null
unzip -tq "$BUNDLE_ZIP" >/dev/null

printf '%s\n' "$PLUGIN_ZIP" "$BUNDLE_ZIP"
