# DeepPipe Mobile QField plugin — API test 0.3.0

This app-wide QField plugin provides two touch-first field workflows:

1. select inlet points directly from the active QField project and submit them to the DeepPipe Prediction API; and
2. choose a map/GNSS location and exercise the pipe service-life Assessment interface.

Version 0.3.0 connects **Prediction** to the configured live API and adds first-use setup for ordinary QField projects plus bulk map selection. **Assessment remains a deterministic mock** until the PyPASS service contract and raster deployment are ready.

## Install

Install `deeppipe-mobile-v0.3.0.zip`. Its `main.qml` is at the ZIP root, as required for an app-wide QField plugin.

1. Host the ZIP at an HTTPS URL reachable by the phone.
2. In QField, open **Settings → Plugins → Install plugin from URL**.
3. Paste the ZIP URL and enable **DeepPipe Mobile**.
4. Open the included `DeepPipe_Mobile_Demo.qgs` project or any project containing an inlet point layer.
5. Tap the DeepPipe toolbar button.

The first runtime target is QField 4.2.10 “Coral Sea” on Android and iOS.

## First-use project setup

The plugin no longer requires a special DeepPipe project flag. In an ordinary project:

1. Open **Setup**.
2. Choose the inlet point layer.
3. Choose its stable unique ID field.
4. Tap **Use this project setup**.

That mapping is stored locally for the project on the current device. For team-wide defaults, these optional read-only project properties can prefill the same mapping:

| Scope | Key | Example |
|---|---|---|
| `DeepPipe` | `schema_version` | `1.0` |
| `DeepPipe` | `inlet_layer` | `Inlets` |
| `DeepPipe` | `node_id_field` | `inlet_uuid` |
| `DeepPipe` | `api_base_url` | `https://lab.yyworkshop.com/predapi` |
| `DeepPipe` | `api_mode` | `live` |

## Live Prediction workflow

1. Open **Prediction** and tap **Select inlets on map**. The full-screen panel closes automatically.
2. Use **Tap** for individual add/remove, **Box** to drag a rectangle around many points, or **Visible** to add every inlet in the current map view; then tap **Done**.
3. Select at least three valid point features.
4. Review maximum distance and confidence threshold.
5. Tap **Predict pipes**.

The plugin transforms selected points to EPSG:4326, sends a GeoJSON FeatureCollection to `POST /api/pred/pred_deep`, saves the returned task ID, polls status, downloads `Pipes.geojson`, and adds a temporary WGS84 result layer. A pending task resumes when the same project is reopened. Submission is never retried automatically after an ambiguous timeout, which avoids accidental duplicate jobs.

Use **Setup → Test API connection** before the first submission. Setup also provides a mock fallback that makes no network call.

For multiple users or offline collection, configure a text UUID field with the QGIS default expression `uuid('WithoutBraces')`. Leave “apply default on update” disabled so the identifier is generated once and remains stable.

## Important test-only limitations

- The configured API currently advertises no authentication. Do not send sensitive field data.
- The API returns only threshold-filtered pipes, so the potential-pipe count is unavailable.
- The current backend implementation must still be verified/fixed for feet-based distance handling when the phone submits EPSG:4326 coordinates. Treat live output as experimental review data, not an engineering determination.
- Result layers are in-memory and disappear when the project closes.
- Only the saved task ID is queried; the plugin never calls the global jobs list.
- Assessment values remain `mock_preview` fixtures and are not PyPASS engineering estimates.

See the bundle-level `docs/TESTING.md` for the complete device test matrix.
