# DeepPipe Mobile for QField — v0.7.0

DeepPipe Mobile is an app-wide QField plugin for Progressive GNN pipe prediction and PyPASS service-life assessment. QField supplies the map, project layers, selection, and GNSS; the plugin calls the same Prediction service as the web app.

## Install

In QField, open **Settings → Plugins → Install plugin from URL** and enter:

```text
https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/mobile/deeppipe-mobile-latest.zip
```

The current server uses a self-signed certificate and requires network access to the campus host. Installation and API requests in QField require that certificate to be trusted on the device, or a deployment proxy with a trusted certificate. The existing public lab endpoint does not serve this Progressive release.

Enable **DeepPipe Mobile**, then import the editable 50-point template below or open an ordinary QField project with an inlet point layer. The plugin installer returns ZIP bytes directly, with `main.qml` at its root. The versioned plugin package is `dist/deeppipe-mobile-v0.7.0.zip`; `dist/deeppipe-mobile-latest.zip` contains the same bytes.

## Editable 50-point project template

The project contains the same 50 Raleigh inlet locations as the Portal's Web App sample, with the original inventory IDs preserved. Its local GeoPackage supports moving points, editing attributes, adding more points, and deleting points. New inlets receive a stable UUID automatically. Save edits before selecting inlets for a new prediction; changing the input of an existing job requires a new prediction.

Download the project separately from the plugin:

```text
https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/mobile/deeppipe-qfield-template-latest.zip
```

The Portal's **DeepPipe Mobile** page provides its project QR and **Open project in QField** button. The [official project import URI](https://docs.qfield.org/how-to/advanced-how-tos/qr-codes/#compressed-web-projects) is:

```text
qfield://local?import=https%3A%2F%2Feegs4y29nw3lws.charlotte.edu%3A8080%2Fdeeppipe%2Fmobile%2Fdeeppipe-qfield-template-latest.zip
```

Open it on a device with QField installed and accept **Import Confirmation**. The ZIP contains one project with relative data paths, so the external deep-link import can open it automatically. In QField's **Open local files → + → Import URL**, use the QR button to scan the same code; if the imported folder is shown, tap `DeepPipe_Mobile_Demo.qgs`. The Plugin Manager's installer QR control is for plugins, so use the separate project import flow.

For a manual transfer, extract the complete ZIP to a writable folder and open its `.qgs` file without separating it from `data/`. Keep a clean ZIP as a starting template; each imported copy has its own editable data. Local edits do not change the server's template or other users' copies. Project viewing/editing works offline; live prediction needs the campus/VPN connection and trusted server certificate. No reference pipe connections or prefilled observations are included.

See [project instructions](project-template/README.md) for editing and reusing the template. Template version **1.0.0** is independent of plugin version **0.7.0**.

## Predict and add field observations

1. Open **Configuration**, choose the inlet layer, then choose its stable unique ID field and tap **Use this project setup**. The mapping is remembered for that exact project on this device.
2. Open **Pipeline Prediction → Select inlets on map**. Use **Tap**, **Box**, or **Visible**, then **Done**. Select at least four valid points.
3. Tap **Predict pipes**. Optional Progressive settings start with two neighbors per direction, KNN k=12 within 250 ft, three rounds, and maximum spanning forest enabled.
4. Review the green final network. Open **Review candidate connections** to mark a pair **Connected**, **Not connected**, or **Unknown**. To confirm a missing connection, choose **Add confirmed connection on map** and tap two original input inlets.
5. Tap **Update prediction from observations**. Blue confirmed and red dashed rejected observations remain visible during the update; a successful child result becomes the green network. Undo, reset the draft, or clear all observations before updating when needed.

The update sends the complete current observation set. Connected pairs are hard positives; disconnected pairs are hard negatives; unknown pairs are omitted. It uses the parent's saved input and settings, including node IDs and point geometry, rather than the latest map selection or edited inlet coordinates. Start a new prediction to change its inputs or configuration. Conflicting constraints may be rejected, and geographic constraints or missing candidates can still leave a disconnected network.

Only final `class=1` pipes are shown in the current network. A confirmed pipe remains selected even if its raw model score is low. **Model probability** stays separate from the effective 0/1 observation probability. Full scored candidates remain available for review. Results from previous plugin versions can be viewed and exported; run a new Progressive prediction to enable observations.

For multiple users or offline collection, use a text UUID field with the QGIS default `uuid('WithoutBraces')`. Disable **apply default on update**, add non-null/unique constraints, and keep each UUID unchanged after creation. A separate readable display ID can coexist with the UUID.

## Results and service-life assessment

The plugin keeps one latest `DeepPipe Prediction Results` layer and saves its GeoJSON in the project folder. Its legend switch controls the green map display. The attribute table lists every returned property; selecting a row zooms to and highlights the pipe. Export another GeoJSON copy or download the server's complete job ZIP when needed. A successful empty network retains its candidates and observation controls.

Accepted task IDs with their originating API URLs, original inputs, configurations, candidates, and saved/draft observations are stored per project on the device. Reopening that project restores its result and resumes accepted pending jobs. Failed or cancelled updates preserve the prior result and observation draft. Ambiguous POST timeouts are not retried automatically. Results and local settings do not automatically synchronize through QFieldCloud.

**Service Life Assessment** retains its independent point and raster workflows. Choose a map/GNSS point for soil properties and material service-life comparisons. For a hosted XYZ raster, choose material, applicable gauge, and minimum service life; viewing another setting replaces the previous managed raster. Null coverage remains unavailable. PyPASS provides comparisons, not a material recommendation.

Prediction uses `https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/predapi`; PyPASS uses `https://lab.yyworkshop.com`. **Configuration → Check API status** checks both services. A project with `api_mode=mock` supports deterministic local preview; it does not run the server model or observation refinement.

## Source and validation

- `plugin/deeppipe-mobile/`: plugin source.
- `project-template/`: 50 Raleigh inlet points, editable GeoPackage, portable QField project, and source metadata.
- `dist/deeppipe-qfield-template-latest.zip`: standalone project template; versioned copy `deeppipe-qfield-template-v1.0.0.zip`.
- `docs/`: API, architecture, project schema, and testing guidance.
- `tests/`: pure logic, source, read-only live contract, native Qt UI, and mocked QField-host runtime checks.
- `dist/DeepPipe_QField_API_Test_v0.7.0.zip`: optional debugging bundle produced by the build; this is not the plugin installer.

```bash
node tests/test_logic.mjs
node tests/validate_source.mjs
node tests/test_api_contract.mjs
./scripts/test_qml.sh
QT_QPA_PLATFORM=offscreen python3 tests/test_project_template.py
./build.sh
```

Qt tests need Qt 6.5+ with Qt Quick Controls and Qt Test. The project edit test uses native PyQGIS (`python3-qgis` on Debian) in a disposable copy. See [testing guidance](docs/TESTING.md). Automated checks do not establish physical-device import, camera, or background behavior. Complete the Android/iOS QField smoke matrix before field use.

## Release history

### v0.7.0 — 2026-10-29

- Replaced new Prediction submissions with Progressive GNN: Delaunay, KNN, directional candidates, configurable rounds, and optional maximum spanning forest.
- Added full-candidate review and connected/disconnected observations, two-inlet map confirmation, undo/reset/clear, and observation-based child predictions.
- Saved original inputs, settings, candidates, and observation drafts per project so updates remain tied to the original node IDs after project edits or restart.
- Used final selected class for green pipes, keeping raw model scores separate from hard observation probabilities.
- Added native Qt panel and mocked-host runtime tests. Previous results remain viewable; a fresh Progressive prediction is required before editing observations.

### v0.6.1 — 2026-08-10

- Changed the raster action to **View Service Life Raster on Map** and made each successful view replace the prior plugin-managed Service Life raster.
- Added **Clear prediction results**, which clears the map result, table, summary, completed-job reference, and saved per-project restore state.
- Updated the installed plugin description to **DeepPipe Stormwater Pipe Prediction and Service Life Assessment for QField**.

### v0.6.0 — 2026-08-10

- Made Configuration explicitly sequential: a user must choose the inlet layer before its field list becomes available, and changing layers clears the prior ID-field choice instead of carrying a same-named field across layers.
- Moved the primary Predict action ahead of optional model controls. DeepPipe defaults run without extra configuration; a collapsed **Specify prediction settings** section exposes custom controls and a reset-to-default action.
- Restored persistent map display for multi-pipe results by aggregating overlay geometry as `MULTILINESTRING` instead of an unsupported `GEOMETRYCOLLECTION`, with the native single result layer retained as a rendering fallback.
- Reorganized Service Life Assessment into **Point-based query** and **Raster-based query** workflows. A chosen map/GNSS point runs the live query directly; raster queries require only material, applicable gauge, and minimum service life.
- Restored hosted PyPASS raster display through the current public proxy by preserving an encoded terminal dot in tile requests, widened the usable zoom range, and added live PNG tile contract checks.

### v0.5.14 — 2026-08-06 (changes since v0.4.0)

- Reworked the touch-first app-wide interface around **Configuration**, **Pipeline Prediction**, and **Service Life Assessment**. Configuration now stores the inlet layer and UUID field per project, so Prediction starts directly with map selection instead of asking for the layer again.
- Expanded project-specific GNN controls for maximum distance, probability threshold, neighborhood size, MST post-processing, and probability/length weighting. The mobile UI now labels probability as **GNN probability**, omits Elevation, and submits its weight as zero.
- Simplified service setup with built-in Prediction and PyPASS endpoints and one combined status card; removed user-facing API-origin fields and direct COG selection from the mobile workflow.
- Fixed **Tap**, **Box**, and **Visible** inlet selection and highlighting. The point handler is registered only during active selection and released afterward, preserving normal one-finger map panning.
- Classified threshold-qualified GNN-positive pipes after MST as **Predicted** (`class=1`, green) or **Potential** (`class=0`, yellow). Records below the submitted threshold, without a valid probability, or marked GNN-negative are excluded.
- Consolidated results into one persistent `DeepPipe Prediction Results` layer whose legend switch controls the complete green/yellow display. The latest result is saved as a project-local GeoJSON, restored when the project reopens, and replaced by each subsequent successful prediction instead of accumulating duplicate layers.
- Added a dynamic attribute table with every field returned in `Pipes.geojson`, available from both the plugin and a QField map-toolbar action. Selecting a row selects the feature, zooms to its pipe, and temporarily highlights it.
- Retained combined GeoJSON export and added download of the server's complete job ZIP.
- Improved release reliability by synchronizing plugin metadata, source, versioned installer, and `latest.zip`; the stable installer is byte-identical to the tested `v0.5.14` package and is committed with the source. GitHub Actions packaging is now manual validation rather than a dependency for installer publication.

### Earlier foundation

- **v0.4.0:** Connected Prediction and PyPASS Assessment to their live APIs, added combined result export and outcome display layers, and added hosted PyPASS XYZ raster layers.
- **v0.3.0:** Made the app-wide plugin usable with ordinary QField projects, added per-project inlet-layer/unique-ID setup and UUID guidance, and introduced bulk **Tap**, **Box**, and **Visible** map selection.
- **v0.2.0:** Published the initial standalone QField plugin with map-based inlet selection, live Prediction submission and polling, a mock assessment workflow, a demo project, documentation, and automated checks.

## License

No open-source license has been selected. Unless a license is added, the source remains subject to the repository owner's default copyright rights.
