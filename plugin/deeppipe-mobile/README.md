# DeepPipe Mobile QField plugin — API test 0.6.1

This app-wide QField plugin provides two touch-first field workflows:

1. select inlet points directly from the active QField project and submit them to the DeepPipe Prediction API; and
2. run either a point-based or raster-based pipe service-life query.

Version 0.6.1 connects **Pipeline Prediction** and **Service Life Assessment** to their live APIs, requires an explicit layer-then-ID-field mapping in **Configuration**, keeps default prediction settings out of the primary path, supports Tap/Box/Visible inlet selection, persists one latest prediction layer per project, renders multi-pipe Predicted/Potential outcomes in green/yellow with a working legend switch, provides a row-to-map result table and job-ZIP download, exports combined GeoJSON, and displays one replaceable hosted PyPASS XYZ service-life raster.

## Install

Install `deeppipe-mobile-v0.6.1.zip`. Its `main.qml` is at the ZIP root, as required for an app-wide QField plugin.

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
4. Tap **Predict pipes** to use the defaults: GNN, 500 ft, confidence 0.85, k=12, MST enabled, and 50% GNN probability / 50% length weighting.
5. Only when needed, expand **Specify prediction settings (optional)** to customize or reset those values. Elevation weighting remains fixed at zero internally.

The plugin transforms selected points to EPSG:4326, sends a GeoJSON FeatureCollection to `POST /api/pred/pred_deep`, saves the returned task ID, polls status, downloads `Pipes.geojson`, and replaces one persistent `DeepPipe Prediction Results` layer. The backend first retains GNN-positive candidates at or above `classification_threshold`; the plugin then maps final `class=1` to Predicted and final `class=0` to Potential. Exact Charlotte Green/yellow `MULTILINESTRING` overlays follow the single OGR layer's legend visibility, and the native layer remains visible as a fallback. The latest result GeoJSON is saved automatically in the project folder and restored on reopen. The plugin can display every returned field, zoom and highlight a pipe selected in the table, open `/api/jobs/jobs/{task_id}/download` for the server ZIP, and save another combined GeoJSON copy. A pending task resumes when the same project is reopened. Submission is never retried automatically after an ambiguous timeout, which avoids accidental duplicate jobs.

## Service Life Assessment

- **Point-based query:** choose a map point or current GNSS location. The plugin immediately runs the live PyPASS query and shows local soil properties plus material service-life comparisons; gauge-dependent results are shown at the documented point-query gauge.
- **Raster-based query:** choose pipe material, gauge when the material requires one, and minimum service life, then add the hosted XYZ layer to the map. Transparent areas do not meet the selected threshold or have no coverage.

Use **Configuration → Check API status** before the first submission. The status card checks both Prediction and PyPASS; their origins are built into the plugin. A local preview fallback remains available for offline UI testing when the project is configured with `api_mode=mock`.

For multiple users or offline collection, configure a text UUID field with the QGIS default expression `uuid('WithoutBraces')`. Leave “apply default on update” disabled so the identifier is generated once and remains stable.

## Important test-only limitations

- The configured API currently advertises no authentication. Do not send sensitive field data.
- The API returns only threshold-filtered GNN-positive pipes; Potential is therefore not a below-threshold class. It means final `class=0` after MST within the threshold-qualified set.
- The current backend implementation must still be verified/fixed for feet-based distance handling when the phone submits EPSG:4326 coordinates. Treat live output as experimental review data, not an engineering determination.
- The latest result is stored as a project-local GeoJSON and restored on reopen; it is not automatically synchronized through QFieldCloud.
- Only the saved task ID is queried; the plugin never calls the global jobs list.
- A particular job may legitimately contain zero Potential features when every returned candidate has final `class=1`.
- PyPASS returns service-life comparisons, not a material recommendation.
- Hosted soil/service-life rasters are loaded as XYZ layers. Direct COG selection is not part of the mobile workflow.

See the bundle-level `docs/TESTING.md` for the complete device test matrix.
