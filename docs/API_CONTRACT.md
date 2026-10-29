# DeepPipe Mobile API contract — v0.7.0

New predictions use the Progressive service at `https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/predapi`. This current campus-server origin includes `/deeppipe`. The older `https://lab.yyworkshop.com/predapi` serves the earlier backend; sending new fields there does not establish a Progressive run. Campus-host network access and a trusted certificate path are required. Its present self-signed certificate must be trusted by the device, or the service must be exposed through a proxy with a trusted certificate. PyPASS remains at `https://lab.yyworkshop.com`.

## Health and submission

`GET /health` expects `{"status":"ok"}`; extra fields such as `device` may be present. Health proves HTTP liveness, not complete queue/model/factor readiness.

The plugin submits selected inlet features directly as JSON to `POST /api/pred/pred_deep`. There is no mobile multipart upload step. At least four valid points are required, with unique stable string/integer IDs and an explicit WGS84 CRS. UUIDs are preserved from the project; they are never regenerated during submission.

```json
{
  "nodes": {
    "type": "FeatureCollection",
    "crs": {"type": "name", "properties": {"name": "EPSG:4326"}},
    "features": [
      {"type":"Feature","properties":{"node_id":"A","source_fid":1},"geometry":{"type":"Point","coordinates":[-80.8431,35.2271]}},
      {"type":"Feature","properties":{"node_id":"B","source_fid":2},"geometry":{"type":"Point","coordinates":[-80.8428,35.2272]}},
      {"type":"Feature","properties":{"node_id":"C","source_fid":3},"geometry":{"type":"Point","coordinates":[-80.8425,35.2275]}},
      {"type":"Feature","properties":{"node_id":"D","source_fid":4},"geometry":{"type":"Point","coordinates":[-80.8429,35.2276]}}
    ]
  },
  "node_id_field": "node_id",
  "workflow_type": "progressive",
  "model_type": "progressive_gnn",
  "progressive_config": {
    "neighbors_per_sector": 2,
    "knn_k": 12,
    "knn_max_distance_ft": 250,
    "rounds": 3,
    "use_msf": true
  }
}
```

Candidate generation combines Delaunay, KNN, and four direction sectors. The mobile controls allow 1–8 neighbors per direction, KNN 1–50, KNN distance 1–5000 ft, and 1–10 rounds. Distance is in US survey feet and limits the KNN candidates. The MSF switch controls maximum spanning forest post-processing. The request excludes legacy threshold/tolerance, MST, and probability/elevation/length weight fields.

An accepted response identifies the queued task, for example:

```json
{"job_id":"abc123def456","task_id":"abc123def456","status":"queued"}
```

The accepted ID is persisted immediately. Neither initial prediction nor refinement POST is automatically retried after an ambiguous timeout.

## Poll and retrieve

These paths are relative to the Prediction origin. The double `jobs/jobs` segment is intentional.

```http
GET /api/jobs/jobs/{task_id}/status
GET /api/jobs/jobs/{task_id}/files
GET /api/jobs/jobs/{task_id}/geojson/Candidates.geojson
GET /api/jobs/jobs/{task_id}/geojson/Pipes.geojson
GET /api/jobs/jobs/{task_id}/download
POST /api/jobs/jobs/{task_id}/cancel
```

Status may contain `status`, Celery `state`, and `info.step`. The client normalizes queued/running/succeeded/failed/cancelled states, backs off transient GET failures, and resumes an accepted task when the same project is reopened. It never queries a global jobs list. Each saved/pending task retains its original API base URL; polling, downloads, cancellation, and refinement remain pinned to that backend rather than adopting a later default.

After success, the client checks `/files`, retrieves full `Candidates.geojson`, and loads the final pipe-named GeoJSON. It does not substitute `Structures.geojson` for missing pipes. Result geometry is WGS84. The job ZIP also provides server files such as structures, candidates, pipes, and logs; metadata/summary files may also be present.

`Pipes.geojson` contains the final selected network. Final `class=1` is authoritative, including confirmed connections whose raw model score is below 0.5. Unselected `class=0` candidates stay in the candidate review list and are not yellow alternatives on the final map. Current pipe export adds `deeppipe_outcome=predicted` and `deeppipe_color=#005035`.

`model_prob`/`neural_probability` retain the raw neural score. `prob`, `effective_prob`, and `effective_probability` describe the effective selection score where provided; connected/disconnected observations override that effective value to 1/0. An unscored manual pair remains unscored in the model column, rather than receiving a fabricated neural score.

## Refine from observations

```http
POST /api/pred/jobs/{parent_task_id}/refine
Content-Type: application/json
```

```json
{
  "observations": [
    {"node_u":"A","node_v":"B","state":"connected"},
    {"node_u":"B","node_v":"C","state":"disconnected"}
  ]
}
```

This is a complete snapshot. **Unknown** removes the pair from the list; `{"observations":[]}` clears all earlier observations. Pairs are undirected, canonicalized by their original stable IDs, and deduplicated. Empty/unsupported IDs, self-pairs, unknown endpoints, and contradictory duplicates are invalid. Numeric `7` and text `"7"` address the same original ID, while leading zeroes remain significant.

The server creates a child task using its parent request/input/settings. The plugin also retains an immutable original WGS84 point snapshot for observation geometry and two-inlet map picking. A manually confirmed pair may be outside the original candidate set; the server incorporates the requested pair during refinement. An update does not adopt newly selected points, edited node IDs/geometry, or subsequently changed configuration controls. Those require a new prediction.

Connected pairs are hard positives and disconnected pairs hard negatives. Crossing/cycle or other incompatible constraints can produce a validation error; neither the client nor MSF guarantees a feasible connected graph for arbitrary observations. Failed/cancelled children preserve the parent result and current draft. On success, the child's result and applied observations become the saved state.

Previous-version results without the required Progressive input snapshot are viewable/exportable. Observation refinement is disabled until a fresh Progressive prediction supplies that snapshot.

## Errors

FastAPI schema validation can return:

```json
{"detail":[{"loc":["body","nodes"],"msg":"Field required","type":"missing"}]}
```

Observation validation may return an object in `detail`, for example `{"field":"observations","message":"..."}`. The client also reads string `detail`, nested errors, HTTP errors, malformed responses, network failure, and timeout. Messages remain visible without discarding the editable observation snapshot.

## PyPASS point and raster APIs

The PyPASS behavior is unchanged. At `https://lab.yyworkshop.com`:

```http
POST /api/pypass/service-life
GET /api/pypass/variables
GET /api/pypass/service-life-layer/options
```

A point request includes latitude/longitude, `nominal_diameter_cast_iron:16`, and a location ID. Responses contain nullable soil values, fixed-material estimates, gauge rows, and warnings. Null coverage remains unavailable and is not converted to zero. The UI presents comparisons rather than a material recommendation.

Raster templates are resolved against the PyPASS origin and loaded through QGIS's XYZ/WMS provider. The public proxy requires the terminal `.png` dot to be transported as `%2Epng`, then percent-escaped inside the QGIS URI. The live contract check verifies in-bounds soil and service-life PNG tiles. Gauge choices are checked against each material's advertised `gauge_sizes`; unsupported values use its `default_gauge` with a status message. Direct COG/GeoTIFF URL selection is not exposed.

## Verification limits

`tests/test_api_contract.mjs` checks live health/OpenAPI, the Progressive defaults and refinement route, a malformed prediction request that cannot enqueue a job, and PyPASS responses. It does not create a real prediction/refinement job. Native Qt tests cover UI bindings and mocked-host request lifecycle; physical QField testing and a controlled synthetic end-to-end server run remain separate checks.
