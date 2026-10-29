#!/bin/sh
# Compile the complete shipped runtime with explicit TEST-ONLY host APIs.
# No shipped source is changed. The only temporary-source substitution maps
# QField's compiled resource import to the declared GeometryRenderer fake.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/deeppipe-runtime-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
mkdir -p "$test_dir/runtime" "$test_dir/tests" "$test_dir/settings"
cp -R "$repo_dir/plugin/deeppipe-mobile/." "$test_dir/runtime/"
sed 's|import "qrc:/qml" as QFieldItems|import "../qfieldqml" as QFieldItems|' \
    "$repo_dir/plugin/deeppipe-mobile/main.qml" > "$test_dir/runtime/Main.qml"
cp -R "$repo_dir/tests/qml/stubs/qfieldqml" "$test_dir/qfieldqml"
cp "$repo_dir/tests/qml/runtime/RuntimeHarness.qml" "$test_dir/tests/tst_Runtime.qml"
export XDG_CONFIG_HOME="$test_dir/settings"
"${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}" \
    -import "$repo_dir/tests/qml/stubs/imports" -input "$test_dir/tests" "$@"
