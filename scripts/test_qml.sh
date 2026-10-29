#!/bin/sh
# Native Qt Quick Controls tests. Requires Qt 6.5+ and QtQuick, Controls,
# Layouts, Templates, QtTest, and QtQml.WorkerScript QML modules.
# This does not load the QField/QGIS native SDK or replace device testing.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -n "${QMLTESTRUNNER:-}" ]; then
    runner=$QMLTESTRUNNER
elif command -v qmltestrunner >/dev/null 2>&1; then
    runner=$(command -v qmltestrunner)
elif [ -x /usr/lib/qt6/bin/qmltestrunner ]; then
    runner=/usr/lib/qt6/bin/qmltestrunner
else
    echo "Qt 6 qmltestrunner is required (or set QMLTESTRUNNER)." >&2
    exit 1
fi
export QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen}
export QSG_RHI_BACKEND=${QSG_RHI_BACKEND:-software}
export LANG=${LANG:-C.UTF-8}
"$runner" -input "$repo_dir/tests/qml" "$@"
QMLTESTRUNNER="$runner" "$repo_dir/tests/qml/run_runtime.sh" "$@"
