# DeepPipe Mobile demo project

`DeepPipe_Mobile_Demo.qgs` is a lightweight QGIS/QField project containing ten **synthetic** inlet points near central Charlotte. It is only for plugin interaction testing.

Keep the project file and `data/inlets.geojson` in the same relative structure when transferring or packaging the project. The project custom properties map the app-wide plugin to:

- inlet layer: `Inlets`
- node ID field: `node_id`
- schema version: `1.0`
- Prediction API base: `https://lab.yyworkshop.com/predapi`
- initial transport mode: `live` (a mock fallback remains in Setup)

The GeoJSON source is convenient for this portable test project. Use only these synthetic points when first exercising the unauthenticated test API. Replace the source with a GeoPackage layer before a real field deployment so edits, constraints, offline synchronization, and result storage can be tested under the intended production conditions.
