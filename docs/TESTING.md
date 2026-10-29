# DeepPipe Mobile v0.7.0 testing

Automated logic, native Qt UI, and mocked-host runtime checks are separate from physical QField validation. Do not report Android/iOS support as tested solely because the automated checks pass.

## Automated checks

```bash
node tests/test_logic.mjs
node tests/validate_source.mjs
node tests/test_api_contract.mjs
./scripts/test_qml.sh
./build.sh
```

- **Pure JavaScript:** Progressive defaults/payload and legacy-setting migration, stable IDs, complete observation snapshots, original-pair geometry, score preservation, undo/reset/clear, project isolation, saved drafts, and empty networks.
- **Source/package:** metadata/version consistency, QML structure, Progressive controls and signal wiring, no legacy settings in new prediction requests, demo UUIDs, and ZIP integrity.
- **Live contract:** health/OpenAPI, Progressive/refinement route and defaults, malformed submission validation that cannot queue a prediction, and PyPASS point/catalog/PNG responses. It does not enqueue a real prediction or refinement.
- **Native Qt:** the actual panel with Qt Quick Controls, including setting interactions, observation choices, action signals, busy state, modal closure, and mobile-width layout.
- **Mocked-host runtime:** the shipped main QML against explicit test-only QField/QGIS/geometry APIs, exercising submissions, complete-snapshot refinement, immutable input, result commit, cancellation/failure, project switching, and saved task/result state.

The QML runner requires Qt 6.5+ and QtQuick, Controls, Layouts, Templates, QtTest, and QtQml.WorkerScript modules. Qt 6.8.2 is used for the local native harness. Set `QMLTESTRUNNER` if it is not on the standard path. `QT_QPA_PLATFORM=offscreen` and the software renderer are defaults. Runtime tests use a temporary source copy with declared host mocks; they do not load the QField/QGIS SDK, render real providers, use GNSS, or establish phone background/network behavior.

The live API script also needs certificate trust for its target origin. For the current self-signed deployment, configure Node's trust using the deployment certificate, for example with `NODE_EXTRA_CA_CERTS`, before running that check.

The separate opt-in test creates an initial prediction and two refinements, then deletes only its own jobs:

```bash
DEEPPIPE_RUN_LIVE_PREDICTION=1 node tests/test_live_progressive.mjs
```

It uses the ten synthetic demo points by default. `DEEPPIPE_API_BASE_URL`, `DEEPPIPE_LIVE_FIXTURE` (WGS84 GeoJSON), and `DEEPPIPE_LIVE_ID_FIELD` can select another controlled fixture and service. It verifies confirmation of a pair outside the original candidates, exclusion of an existing pipe, changes to unknown neural scores, and restoration of the original candidates/scores after an empty observation snapshot.

On 2026-10-29, the release checks passed with 44 native Qt cases (including test setup/teardown), pure-JS/source checks, and the live API contract. The opt-in workflow passed against the current server using the Portal's 50-node Raleigh fixture: 225 initial candidates, an added outside pair, an excluded existing pipe, 191 changed unknown scores, and restoration of the unconditioned baseline after clearing. All three test jobs were deleted. This checks constraint behavior and workflow integration; it does not measure prediction accuracy or replace a physical-device test.

Build outputs are `dist/deeppipe-mobile-v0.7.0.zip` and byte-identical `dist/deeppipe-mobile-latest.zip`. The optional `DeepPipe_QField_API_Test_v0.7.0.zip` is a debugging bundle, not an app-wide plugin installer.

## Physical-device setup required

Use QField 4.2.10 or the deployment's supported current QField version on an Android phone and an iPhone/iPad. Record exact versions. Test portrait/landscape, Wi-Fi/cellular, loss of connectivity, and background/lock-screen resume. Start with the ten synthetic demo inlets; use non-sensitive controlled inputs for live server smoke tests.

The release currently targets:

- Installer: `https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/mobile/deeppipe-mobile-latest.zip`
- Prediction: `https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/predapi`
- PyPASS: `https://lab.yyworkshop.com`

The campus host must be reachable from the phone's network. Its self-signed certificate requires device trust or a deployment proxy with a trusted certificate. Check actual QField HTTP/install behavior; browser success alone is insufficient. The older public lab `/predapi` service does not supply this Progressive workflow. Do not treat accepting unknown request fields as evidence that the model ran Progressive inference.

## Install and project lifecycle

| Test | Expected |
|---|---|
| Install the v0.7.0 direct ZIP and enable plugin | One DeepPipe toolbar entry; correct version. |
| No project / project without point layers | Actionable setup guidance; no crash. |
| Fresh ordinary project | No silent layer selection; ID field disabled until a layer is chosen. |
| Change inlet layer A to B | Prior field choice clears, even for same-named fields. |
| Confirm/reopen | Mapping and custom Progressive settings restore for that exact project. |
| Open same-title projects at distinct paths | No mapping/configuration/result/draft/task leakage. |
| Optional settings expand/reset | Defaults: direction 2, KNN 12, 250 ft, rounds 3, MSF on; no legacy threshold/weight controls. |
| Rename/remove configured field | Prediction blocks until a valid mapping is confirmed. |
| Disable/re-enable or rotate | No duplicate handlers/buttons; controls remain usable. |
| Fresh install/idle | First-touch map panning works; no selection handler is registered while idle. |
| Previous-version result | View/export works; observations require a fresh Progressive prediction. |

## Inlet and observation map interaction

| Test | Expected |
|---|---|
| Start inlet selection | Panel closes; Tap/Box/Visible toolbar appears. |
| Tap point twice / tap empty map | Adds/removes once; empty taps only show guidance. |
| Dense points | Nearest inlet within tap tolerance toggles. |
| Box/Visible repeated | All matching inlets added once; no duplicates. |
| Tiny box / rapid taps | Guidance/throttling; no accidental duplicate selection. |
| 100–500 inlets via bulk selection | Responsive batching and native highlighting. |
| Existing native selection / local unsynchronized point | Eligible saved features can be selected. |
| Different project/inlet CRS | Tap/box hit tests and WGS84 submission remain correct. |
| Missing/duplicate/invalid node IDs | Submission blocks with readable validation. |
| Fewer than four points | Predict disabled. |
| Finish any map interaction | Normal one-finger panning returns. |
| Add confirmed pair | Two original input inlet picks create one blue confirmation; self-pair blocked. |
| Source features moved, renamed, removed, or reselected after prediction | Pair picking/geometry still uses the original input snapshot. |

Test both EPSG:4326 and a projected inlet layer. Provider FIDs must never replace the chosen stable UUID identity.

## Progressive live prediction

1. Check both services in Configuration.
2. Select at least four synthetic inlets and submit once.
3. Record task ID, endpoint, elapsed time, and model/workflow metadata from the server output.

| Test | Expected |
|---|---|
| Inspect new request | `workflow_type=progressive`, `model_type=progressive_gnn`, correct nested configuration, WGS84 points. |
| Tap Predict twice | One POST; busy controls block resubmission. |
| Queued/running/fetching | Busy animation/messages update; accepted ID is retained. |
| Reopen/background/network loss | Existing task resumes GET polling; no second POST. |
| Change application default backend | Accepted task still polls/downloads/cancels against its saved origin. |
| Ambiguous submit timeout | No automatic POST retry; readable status. |
| Successful final result | One green final network with `class=1`; full Candidates available separately. |
| Confirmed low model score | Selected green pipe remains present; raw score stays distinct from effective 1. |
| Multiple pipes | All render without selecting a table row. |
| Legend visibility | Result and green overlay toggle together. |
| Next successful run | Replaces one latest layer/file, rather than accumulating layers. |
| Successful empty network | Zero-pipe success with candidates and observation actions still available. |
| Missing Pipes / Candidates retrieval fails | No substitute Structures layer or partial new-result commit. |
| Reopen result | Layer, attributes, original inputs, settings, candidates, and saved/draft observations restore. |
| Table/map toolbar action | All final attributes visible; tapping a row zooms/selects/highlights its pipe. |
| Save/share GeoJSON and job ZIP | Geometry/CRS/IDs/scores remain intact; complete server files downloadable. |
| Clear prediction results | Layer, table, saved restore state, result snapshots, and completed reference clear. |

## Observation refinement

| Test | Expected |
|---|---|
| Review candidates | Selected and unselected pairs visible with raw model scores; unscored remains unscored. |
| Connected / Not connected / Unknown | Draft canonicalizes undirected pair; unknown removes its observation. |
| Add missing confirmed pair | Original endpoint geometry shown; pair included in complete refine snapshot. |
| Undo / Reset draft / Clear all | Undo last edit, restore applied snapshot, or clear all respectively. |
| Update with empty snapshot | Sends `observations:[]` to remove prior constraints. |
| Inspect refine POST | Parent-specific route; complete current snapshot, not an incremental patch. |
| Configuration or selection changed after parent | Update retains parent's saved configuration/input; a new prediction is needed for new inputs/settings. |
| Update while a table is open | Modals close; busy animation and blue/red-dashed constraints appear while waiting. |
| Successful update | Confirmations selected green, rejected edges absent, new candidate scores available, temporary overlays hidden. |
| Contradictory/crossing/cycle constraints | Readable server validation; previous result and draft remain. |
| Cancel/error/transient download failure | Parent stays intact; no duplicate refine POST; draft remains available. |
| Reopen accepted child task | Resume against saved backend with original inputs/configuration/snapshot. |
| Project switch during request/selection | Old callbacks/picks cannot change the new project's state. |

Do not require the server to connect every graph: hard observations, geometry, and candidate coverage can make that impossible. Confirm that no rejected edge is silently restored merely to force connectivity.

## Unchanged PyPASS regression smoke

| Test | Expected |
|---|---|
| Map/GNSS point query | Runs automatically, returns soil values and material comparisons. |
| Partial coverage | Null soil/material values stay Unavailable; warnings visible. |
| Point gauge | Gauge-dependent point values use 16; raster controls do not change the point result. |
| Fixed/gauge-dependent raster material | Gauge disabled where inapplicable, otherwise valid catalog choices. |
| View raster | Material/gauge/threshold reflected in name/URL; replaces prior managed raster and returns to map. |
| Regional/local zoom | Hosted tiles render; transparency indicates coverage/threshold. |
| Encoded-dot tile request | HTTP PNG response rather than the frontend's literal-dot routing response. |
| Unsupported gauge | Advertised material default used with a message. |
| Project switch/unload | Managed raster layers removed cleanly. |

## Record and remaining limits

Record device/OS/QField versions, project and layer CRS, stable ID field, input count, originating API, task/parent IDs, submit/result timing, network transitions, and any clipped controls or QField log errors. Verify physical gestures, map provider rendering, certificate trust, exports/share sheet, GNSS, restart, and background recovery on both platforms.

Latest-result files and local mappings/configuration/observations are not automatically synchronized through QFieldCloud. Mock mode is a deterministic local preview, not proof of Progressive model/refinement behavior. Direct COG/GeoTIFF URL selection is outside this mobile workflow.
