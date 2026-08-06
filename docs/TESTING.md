# DeepPipe Mobile 0.5.14 test matrix

## Baseline

- QField 4.2.10 “Coral Sea”.
- One current Android phone and one current iPhone/iPad.
- Included synthetic demo plus a copy of one real DeepPipe field project.
- Portrait and landscape.
- Wi-Fi, cellular, airplane mode, weak/intermittent connectivity, background/lock-screen resume.

Use only synthetic/non-sensitive inlets against the current unauthenticated test API.

## Installation and project lifecycle

| Test | Expected |
|---|---|
| Install `deeppipe-mobile-v0.5.14.zip` from HTTPS | Plugin appears as DeepPipe Mobile and can be enabled. |
| Open QField with no project | Toolbar/panel stay safe and report that a project must be opened. |
| Open a plain project with no point layer | Configuration explains that an inlet point layer is required; Assessment remains available once a map project is open. |
| Open a plain project with one/multiple point layers | Configuration suggests or lists point layers; user can choose a layer and ID field without editing project XML. |
| Confirm setup, close, and reopen | The same project mapping is restored on this device. |
| Open Pipeline Prediction after setup | The configured inlet layer is shown in the selection instructions; no second layer chooser is present. |
| Open demo project | `Inlets` and `inlet_uuid` resolve from project defaults. |
| Switch to another ordinary project | Selection/result state clears; the other project gets its own mapping; a server job is not silently cancelled. |
| Open two same-title projects at different paths | Their mappings, prediction settings, and pending jobs do not cross-contaminate. |
| Configure prediction settings in project A, then open unconfigured project B | Project B uses the documented prediction defaults; no setting from project A remains. Reopening A restores only A's local settings. |
| Rename/remove the configured field | Configuration becomes actionable and blocks Prediction until a valid field is confirmed. |
| Disable/re-enable plugin | No duplicate toolbar buttons or tap handlers after restart. |
| Fresh install, before opening DeepPipe | One-finger map pan works immediately; the plugin does not reserve map taps while idle. |
| Rotate with panel open | Drawer, selection bar, and action buttons remain usable. |

## Touch inlet selection

| Test | Expected |
|---|---|
| Start selection | Drawer closes and bottom selection bar appears. |
| Tap a point / tap it again | Exactly one inlet is added / removed. |
| Dense points inside the tap tolerance | The nearest point is toggled. |
| Switch to Box and drag a rectangle | All inlets intersecting the rectangle are added in one batch; map count updates once. |
| Drag a tiny rectangle | Guidance appears; no accidental selection occurs. |
| Repeat the same box | Existing inlets are not duplicated. |
| Tap Visible | Every inlet in the current map view is added once. |
| Select 100–500 points by Box/Visible | QField remains responsive and native selection updates as one batch. |
| Switch back to Tap | Map taps work for individual corrections. |
| Tap empty map | Guidance toast appears; count is unchanged. |
| Rapid double tap | Handler throttles and QField remains responsive. |
| Native selection exists first | Starting DeepPipe selection imports it. |
| Local unsynchronized inlet | Saved local feature can be selected and submitted. |
| Project CRS differs from inlet CRS | Tap hit-testing remains correct after `QgsPoint` screen-bound conversion and rectangle reprojection. |
| Choose a non-point layer | It is absent from the inlet-layer chooser. |

Test both EPSG:4326 and a projected North Carolina inlet layer. The current hit rectangle is 16 logical pixels around the tap.

## Validation and request snapshot

| Case | Expected |
|---|---|
| Fewer than 3 points | Predict button remains disabled. |
| Missing/empty node ID | Submission blocks with a feature-specific message. |
| Duplicate node ID | Submission blocks; server-side silent dropping is avoided. |
| UUID values from multiple offline users | Unique text UUIDs pass; duplicated UUIDs block submission. |
| Invalid WGS84 transformation | Live submission blocks. |
| Valid projected points | Request coordinates are transformed to `[longitude, latitude]` and CRS is `EPSG:4326`. |
| Tap Predict twice quickly | Only one POST occurs; all busy states disable resubmission. |

## Live Prediction API

1. Open **Configuration** and tap **Check API status**.
2. Expect both Prediction and PyPASS to show `Online` (the Prediction device text may change).
3. Select one controlled synthetic group of at least three inlets and submit once.
4. Record the task ID shown in the panel.

| Test | Expected |
|---|---|
| Successful submit | HTTP 200 is treated as queued; task ID is displayed and persisted. |
| Queued/running | Panel updates without blocking QField map use. |
| Close/reopen same project | Saved task resumes polling; no second POST occurs. |
| Background/lock phone | Polling resumes when QField becomes active again or project is reopened. |
| Weak/temporary network loss | Task ID remains saved; GET polling backs off and retries. |
| Submit response timeout | Plugin does not auto-retry POST and explains duplicate-job risk. |
| Cancel active task | Only the stored task ID is cancelled; terminal status is shown. |
| Successful non-empty result | Threshold-qualified `Pipes.geojson` features become one layer named `DeepPipe Prediction Results`; map overlays draw Predicted green and Potential yellow. |
| Toggle result in legend | The single result layer and both colored overlays turn off/on together. |
| Run a second successful prediction | The prior result layer is removed, the same latest-result file is replaced, and exactly one result layer remains. |
| Restart QField/reopen project | The latest saved result layer, colors, table, and completed job ID are restored automatically. |
| Successful empty result | Success with 0 pipes; plugin does not try to create an empty memory layer. |
| `Structures.geojson` exists but Pipes is missing | Plugin waits; it never loads Structures as a pipe layer. |
| Remove result | The plugin-created layer disappears and is no longer restored for that project. |
| Export result | Combined `DeepPipe_prediction_<job-id>.geojson` is written directly in the existing project folder (or device Documents fallback); geometry, CRS, outcome, and job fields survive a reload. |
| Attribute table | **View result attribute table** and the map-actions result icon show every returned Predicted/Potential row and every property, with horizontal and vertical scrolling. Tapping a row closes the table, zooms to the pipe, selects it, and highlights it. |
| Download complete job ZIP | Device browser opens `/api/jobs/jobs/{task_id}/download`; downloaded ZIP contains the server-provided Structures, Pipes, and log files. |
| Potential outcomes present | Potential count is numeric, yellow Potential geometry is visible, and combined export retains `deeppipe_outcome=potential`. |
| API 400/422/404/500 | FastAPI message is readable; no duplicate submission is attempted. |

Inspect live features for `job_id=<task-id>`, `analysis_mode=live_api`, and `review_status=unreviewed`. Confirm that every displayed feature meets the submitted threshold and has `model_class=1`; final `class=1` must be Predicted and `class=0` must be Potential. A job with no Potential feature must show `0`, not `—`.

## Mock fallback

| Test | Expected |
|---|---|
| Use a demo project with `api_mode=mock` | Header shows MOCK; Predict becomes local Preview. |
| Same mock inputs/settings | Same topology/probabilities each run. |

## Live PyPASS Assessment and raster review

| Test | Expected |
|---|---|
| Wilmington controlled point | Live soil values and seven material rows are shown. |
| Location with partial coverage | Null soil/material values display `Unavailable`; server warnings are visible. |
| Choose a fixed material (for example RCP) | Gauge selector is disabled and the live comparison uses no gauge. |
| Choose a gauge-dependent material | Gauge selector is enabled and only its advertised gauge values can be chosen. |
| Change selected gauge | The comparison uses the matching gauge-dependent material row. |
| Inspect language | Results are comparisons and never claim a recommended material. |
| Add pH/resistivity/chloride | Catalog `tile_url` is resolved against the PyPASS origin and the XYZ layer appears. |
| Add service-life layer | Material, threshold, and required gauge are reflected in the layer name and tile URL. |
| Add Aluminum/Aluminized CSP with gauge 18 | Catalog validation uses the material's advertised default gauge and reports the adjustment instead of requesting invalid tiles. |
| Project switch/plugin unload | Plugin-created raster layers are removed cleanly. |

## Record during device testing

- QField/OS/device versions.
- Project CRS, inlet CRS, inlet count, and selected count.
- Health request result, submit-to-task-ID time, total job time, and result-layer load time.
- Network transitions and whether recovery required user action.
- Any QField log message, crash, duplicated request, wrong map position, clipped control, or lost task ID.

## Known limitations and stop conditions

- The current API advertises no authentication or task ownership. Do not use sensitive data.
- `/health` proves only the web process responds; it is not a model/worker readiness guarantee.
- Verify/fix server-side feet-based distance calculations for EPSG:4326 before interpreting model output.
- One latest-result GeoJSON is persisted per project and restored by the plugin, but no automatic GeoPackage/QFieldCloud result sync exists yet.
- Interactive project mappings are local to one device. Put optional DeepPipe defaults in the QGIS project when every team device should receive the same mapping.
- Direct COG/GeoTIFF selection is intentionally out of scope for the mobile plugin; raster review uses the PyPASS XYZ catalog.
- Exact green/yellow colors are supplied by non-interactive map overlays bound to one transparent OGR layer's legend visibility. Persistent production layers should own their rule-based QGIS styles.
