# DeepPipe Mobile QField plugin — API test 0.5.12

This app-wide QField plugin provides two touch-first field workflows:

1. select inlet points directly from the active QField project and submit them to the DeepPipe Prediction API; and
2. choose a map/GNSS location and exercise the pipe service-life Assessment interface.

Version 0.5.12 connects **Pipeline Prediction** and **Service Life Assessment** to their live APIs, fixes Tap/Box/Visible inlet selection, uses the layer saved in **Configuration** without a second chooser, adds result export, separates returned outcome classes into display layers, adds configurable model settings, and can add hosted PyPASS XYZ rasters.

## Install

Install `deeppipe-mobile-v0.5.12.zip`. Its `main.qml` is at the ZIP root, as required for an app-wide QField plugin.

1. Host the ZIP at an HTTPS URL reachable by the phone.
2. In QField, open **Settings → Plugins → Install plugin from URL**.
3. Paste the ZIP URL and enable **DeepPipe Mobile**.
4. Open the included `DeepPipe_Mobile_Demo.qgs` project or any project containing an inlet point layer.
5. Tap the DeepPipe toolbar button.

The first runtime target is QField 4.2.10 “Coral Sea” on Android and iOS.

## First-use project setup

The plugin no longer requires a special DeepPipe project flag. In an ordinary project:

1. Open **Configuration**.
2. Choose the inlet point layer.
3. Choose its stable unique ID field.
4. Tap **Use this project setup**.

That mapping and the selected prediction settings are stored locally for the exact project on the current device; they do not carry into another same-title project file. For team-wide defaults, these optional read-only project properties can prefill the configuration:

| Scope | Key | Example |
|---|---|---|
| `DeepPipe` | `schema_version` | `1.0` |
| `DeepPipe` | `inlet_layer` | `Inlets` |
| `DeepPipe` | `node_id_field` | `inlet_uuid` |
| `DeepPipe` | `api_mode` | `live` |

## Live Prediction workflow

1. Open **Pipeline Prediction** and tap **Select inlets on map**. The full-screen panel closes automatically.
2. Use **Tap** for individual add/remove, **Box** to drag a rectangle around many points, or **Visible** to add every inlet in the current map view; then tap **Done**.
3. Select at least three valid point features.
4. Review the prediction settings. Defaults are GNN, 500 ft, confidence 0.85, k=12, MST enabled, and 50% GNN probability / 50% length weighting. Elevation weighting is fixed at zero internally and is not shown as a user control.
5. Tap **Predict pipes**.

The plugin transforms selected points to EPSG:4326, sends a GeoJSON FeatureCollection to `POST /api/pred/pred_deep`, saves the returned task ID, polls status, downloads `Pipes.geojson`, and adds temporary WGS84 outcome layers. It normalizes final `class`, `is_connect`, probability/score, explicit outcome aliases, or `model_class` (in that precedence order) into `deeppipe_outcome`; potential and unknown outcomes use separate lower-opacity layers. A combined `DeepPipe_prediction_<job-id>.geojson` file can be saved directly in the existing project folder, or in the device Documents folder when the project has no home path. A pending task resumes when the same project is reopened. Submission is never retried automatically after an ambiguous timeout, which avoids accidental duplicate jobs.

Use **Configuration → Check API status** before the first submission. The status card checks both Prediction and PyPASS; their origins are built into the plugin. A local preview fallback remains available for offline UI testing when the project is configured with `api_mode=mock`.

For multiple users or offline collection, configure a text UUID field with the QGIS default expression `uuid('WithoutBraces')`. Leave “apply default on update” disabled so the identifier is generated once and remains stable.

## Important test-only limitations

- The configured API currently advertises no authentication. Do not send sensitive field data.
- The API returns only threshold-filtered pipes, so the potential-pipe count is unavailable.
- The current backend implementation must still be verified/fixed for feet-based distance handling when the phone submits EPSG:4326 coordinates. Treat live output as experimental review data, not an engineering determination.
- Map result layers are in-memory and disappear when the project closes; use the GeoJSON export action to retain a copy.
- Only the saved task ID is queried; the plugin never calls the global jobs list.
- The deployed Prediction endpoint currently returns only threshold-filtered candidates, so live output may contain no potential layer.
- PyPASS returns service-life comparisons, not a material recommendation.
- Hosted soil/service-life rasters are loaded as XYZ layers. Direct COG selection is not part of the mobile workflow.

See the bundle-level `docs/TESTING.md` for the complete device test matrix.
