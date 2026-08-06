# DeepPipe Mobile demo project

`DeepPipe_Mobile_Demo.qgs` is a lightweight QGIS/QField project containing ten **synthetic** inlet points near central Charlotte. It is only for plugin interaction testing.

Keep the project file and `data/inlets.geojson` in the same relative structure when transferring or packaging the project. The project custom properties map the app-wide plugin to:

- inlet layer: `Inlets`
- prediction ID field: `inlet_uuid`
- human-readable display field: `node_id`
- schema version: `1.0`
- initial transport mode: `live` (a mock fallback remains available in the plugin)

The plugin supplies its Prediction and PyPASS service origins. Open the
**Configuration** tab and use **Check API status** to verify both services;
there are no project-level API URL fields to edit.

The ten synthetic features include stable UUID values. New inlet features are configured with the QGIS default expression `uuid('WithoutBraces')` and the UUID field is not editable, demonstrating the recommended multi-user/offline identity pattern.

The GeoJSON source is convenient for this portable test project. Use only these synthetic points when first exercising the unauthenticated test API. Replace the source with a GeoPackage layer before a real field deployment so edits, constraints, offline synchronization, and result storage can be tested under the intended production conditions.
