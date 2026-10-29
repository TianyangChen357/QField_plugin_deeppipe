pragma Singleton
import QtQml

// TEST ONLY: no actual reprojection takes place in this host API fake.
QtObject {
    function wgs84Crs() { return "EPSG:4326"; }
}
