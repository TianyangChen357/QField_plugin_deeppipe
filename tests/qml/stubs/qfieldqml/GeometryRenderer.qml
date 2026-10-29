import QtQuick

// TEST ONLY: records geometry passed to QField's renderer. This is not a
// substitute for testing a QgsGeometry renderer in the actual QField SDK.
Item {
    property var mapSettings
    property color color: "black"
    property real lineWidth: 1
    property QtObject geometryWrapper: QtObject {
        property var crs
        property var qgsGeometry
        function clear() { crs = null; qgsGeometry = null; }
    }
}
