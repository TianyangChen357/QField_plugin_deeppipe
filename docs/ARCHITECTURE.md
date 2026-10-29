# DeepPipe Mobile architecture — v0.7.0

DeepPipe Mobile is one app-wide QField plugin with project-scoped configuration. It uses QField's native map, layers, selection, and GNSS rather than embedding the web portal.

## Boundaries

```text
QField project inlet layer
    → confirmed layer/ID mapping
    → Tap / Box / Visible selection
    → validated immutable WGS84 snapshot
    → Progressive Prediction API
    → full candidates + final pipes
    → field observations → child refinement task
    → latest green result layer + attribute table
```

`main.qml` owns QField integration, task transport, map interaction, and project lifecycle. `DeepPipePanel.qml` presents controls and emits user-action signals. `logic/DeepPipe.js` contains QML-independent configuration, validation, observation normalization, result decoration, and storage helpers.

Prediction uses the fixed `https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/predapi` origin, including `/deeppipe`. PyPASS uses `https://lab.yyworkshop.com`. The Configuration status card checks both; a health response is not a full worker/model readiness guarantee.

## New Prediction lifecycle

1. Discover point layers. Restore a valid device mapping or optional exact project defaults; otherwise require explicit layer-then-ID-field confirmation. Changing layers clears the previous field choice.
2. Key settings and state by exact project path, falling back to title only for pathless projects. Same-title project files remain isolated.
3. Enter inlet-selection mode. Tap toggles the nearest inlet, Box adds a rectangle, and Visible adds the current view. Batch actions update native selection once.
4. Validate at least four points, stable unique IDs, and valid geometry. Transform the selected records to WGS84 and capture their original input snapshot.
5. Submit only the Progressive workflow/configuration. The model builds Delaunay/KNN/directional candidates, runs configured Progressive rounds, and optionally applies maximum spanning forest.
6. Persist the accepted task ID with its input/configuration before polling. Retry transient GET failures with backoff; never automatically retry an ambiguous POST.
7. On success retrieve full Candidates and final Pipes. Trust final `class=1`, even if the neural score is low. Unselected candidates remain reviewable without becoming final-map alternatives.
8. Replace one latest-result GeoJSON and OGR layer, restore it on reopen, and rebuild the full-field attribute table. A successful empty graph retains the task, input, candidates, and observation workflow without creating an empty map layer.

The current green `MULTILINESTRING` overlay follows the single OGR layer's legend visibility. The native renderer remains visible as a fallback; the layer owns selection and attributes. A row action zooms to and temporarily highlights its pipe. The result can be exported again, and the completed task supplies the server ZIP URL.

## Observation lifecycle

The result owns its immutable `input_nodes`, `node_id_field`, `prediction_config`, full candidates, completed job ID, and saved observation snapshot. A separate editable draft plus in-session history support undo, reset-to-saved, and clear-all actions. Draft changes are persisted per project.

Observation pairs use canonical original node IDs, never current row indices/provider FIDs. Connected/disconnected are explicit hard constraints; unknown is omitted. Duplicate equal states collapse; contradictions, invalid/self-pairs, and endpoints outside the original input are rejected. Full candidates supply selected and unselected review rows. Missing manually observed pairs can still have real geometry from the original point snapshot without fabricated model scores.

Two-inlet map selection operates on the original snapshot, so later source-layer edits cannot move or rename an existing result's observations. Confirmed lines are blue and rejected lines red/dashed while editing or submitting. Update sends the complete draft to the parent's `/refine` endpoint. The child retains parent inputs/settings; altered current selection/configuration needs a new prediction.

An accepted child is persisted and polled independently. Successful completion commits its network and applied observation snapshot, then hides temporary observation overlays. Failure/cancellation retains the parent result and draft. Ambiguous POST failure does not issue a duplicate submission. Hard constraints can make a connected solution impossible; the client displays server conflicts without weakening the observations.

Historical results remain viewable/exportable, but cannot refine without a valid Progressive original-input snapshot. Re-running a new prediction establishes the current workflow safely.

## Map interaction

The point handler is registered only during an explicit inlet, observation-pair, or assessment selection and released when finished/cancelled. It does not capture idle startup map taps. Tap/Box/Visible use QGIS point/rectangle values with CRS conversion and close feature iterators. Box mode captures drag gestures until its interaction ends. Observation map picks use immutable WGS84 input features transformed for the current map.

## Persistence

Device settings retain project mapping, normalized Progressive configuration, latest-result metadata, immutable input, candidates, saved/draft observations, and accepted pending tasks. Saved result records use schema version 2; optional QGIS project setup entries remain schema 1.0. Earlier model settings migrate to Progressive defaults, while historical result provenance remains distinguishable from a new Progressive result.

The latest-result GeoJSON lives in the project folder (or Documents fallback). The plugin does not rewrite the `.qgs`/`.qgz` project or automatically synchronize results/settings through QFieldCloud. Production synchronization should use deliberately configured persistent GeoPackage/provider layers with owned schemas, styles, review policy, and sync behavior. In-session undo history is distinct from the persisted saved/draft snapshots.

## Service-life workflows

Point and raster assessment remain independent. A map/GNSS point immediately requests nullable soil values and material service-life comparisons at the explicit point gauge. Raster selection accepts material, applicable gauge, and minimum service life, then replaces one managed hosted XYZ layer. Changing raster controls does not clear a point result. Null coverage stays unavailable; material comparisons are not recommendations.

The PyPASS catalog supplies current tile templates and valid gauge choices. Encoded-dot PNG transport is retained for the deployed proxy. Direct COG/GeoTIFF URL selection is not exposed.

## Test boundaries

Pure JavaScript tests exercise request/configuration, IDs, snapshots, geometry, classification, and persistence. Native Qt Quick Controls tests exercise the shipped panel. Runtime tests compile the shipped main QML against explicit test-only QField/QGIS/geometry host mocks and drive request/observation lifecycle. These tests cannot validate QGIS provider rendering, platform networking, physical gestures, GNSS, or phone background behavior; use the device matrix for those.
