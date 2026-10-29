pragma Singleton
import QtQml

// TEST ONLY: keeps the actual WKT so native QML tests can assert the runtime
// passes solid and dashed MultiLineString geometries to the map renderer.
QtObject {
    function createGeometryFromWkt(wkt) { return {wkt: wkt}; }
    function point(x, y) { return {x: x, y: y}; }
    function reprojectPoint(point, fromCrs, toCrs) { return point; }
    function distanceBetweenPoints(a, b) { return Math.sqrt(Math.pow(a.x - b.x, 2) + Math.pow(a.y - b.y, 2)); }
    function createRectangleFromPoints(a, b) {
        return {xMinimum: Math.min(a.x, b.x), xMaximum: Math.max(a.x, b.x),
                yMinimum: Math.min(a.y, b.y), yMaximum: Math.max(a.y, b.y)};
    }
}
