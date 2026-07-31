# DeepPipe Mobile 0.2.0 test matrix

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
| Install `deeppipe-mobile-v0.2.0.zip` from HTTPS | Plugin appears as DeepPipe Mobile and can be enabled. |
| Open QField with no project | Toolbar/panel stay safe and report that project setup is required. |
| Open demo project | `DeepPipe project detected`; `Inlets` and `node_id` resolve. |
| Switch to non-DeepPipe project | Tools disable; selection/result state clears; a server job is not silently cancelled. |
| Disable/re-enable plugin | No duplicate toolbar buttons or tap handlers after restart. |
| Rotate with panel open | Drawer, selection bar, and action buttons remain usable. |

## Touch inlet selection

| Test | Expected |
|---|---|
| Start selection | Drawer closes and bottom selection bar appears. |
| Tap a point / tap it again | Exactly one inlet is added / removed. |
| Tap empty map | Guidance toast appears; count is unchanged. |
| Rapid double tap | Handler throttles and QField remains responsive. |
| Native selection exists first | Starting DeepPipe selection imports it. |
| Local unsynchronized inlet | Saved local feature can be selected and submitted. |
| Project CRS differs from inlet CRS | Tap hit-testing remains correct after rectangle reprojection. |
| Choose a non-point layer | It is absent from the inlet-layer chooser. |

Test both EPSG:4326 and a projected North Carolina inlet layer. The current hit rectangle is 16 logical pixels around the tap.

## Validation and request snapshot

| Case | Expected |
|---|---|
| Fewer than 3 points | Predict button remains disabled. |
| Missing/empty node ID | Submission blocks with a feature-specific message. |
| Duplicate node ID | Submission blocks; server-side silent dropping is avoided. |
| Invalid WGS84 transformation | Live submission blocks. |
| Valid projected points | Request coordinates are transformed to `[longitude, latitude]` and CRS is `EPSG:4326`. |
| Tap Predict twice quickly | Only one POST occurs; all busy states disable resubmission. |

## Live Prediction API

1. Open **Setup** and confirm the URL is `https://lab.yyworkshop.com/predapi`.
2. Tap **Test API connection**; expect `Connected · cpu` (device text may change).
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
| Successful non-empty result | `Pipes.geojson` becomes WGS84 memory layer `DeepPipe Pipes <job-id>`. |
| Successful empty result | Success with 0 pipes; plugin does not try to create an empty memory layer. |
| `Structures.geojson` exists but Pipes is missing | Plugin waits; it never loads Structures as a pipe layer. |
| Remove result | Only the plugin-created memory layer disappears. |
| API 400/422/404/500 | FastAPI message is readable; no duplicate submission is attempted. |

Inspect a live pipe feature for `job_id=<task-id>`, `analysis_mode=live_api`, and `review_status=unreviewed`. The Potential summary must show `—`, because the API returns only threshold-filtered pipes.

## Mock fallback and Assessment

| Test | Expected |
|---|---|
| Disable live Prediction API in Setup | Header shows MOCK; Predict becomes local Preview. |
| Same mock inputs/settings | Same topology/probabilities each run. |
| Assessment map point / GNSS | Location updates, then deterministic mock values appear. |
| Inspect Assessment language | It clearly says mock/estimate and never claims a recommended material. |

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
- Live layers are temporary; no GeoPackage write or QFieldCloud result sync yet.
- Assessment/PyPASS and soil rasters remain mock/unconnected.
