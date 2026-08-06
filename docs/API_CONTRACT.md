# DeepPipe Mobile API contract — 0.5.0

Prediction was checked against `https://lab.yyworkshop.com/predapi/openapi.json`
on 2026-07-31. PyPASS endpoints were checked live on 2026-08-04.

## Health

```http
GET https://lab.yyworkshop.com/predapi/health
```

Observed response:

```json
{"status":"ok","device":"cpu"}
```

This is a liveness check, not a complete worker/model/factor readiness check.

## Submit selected inlet points

`node_id_field` may name a string UUID field. For multi-user/offline QField collection, the plugin recommends stable UUID strings generated once at feature creation; it does not regenerate IDs during submission.

```http
POST https://lab.yyworkshop.com/predapi/api/pred/pred_deep
Content-Type: application/json
```

The QField plugin submits selected features directly; it does not call the separate multipart upload endpoint.

```json
{
  "nodes": {
    "type": "FeatureCollection",
    "crs": {"type": "name", "properties": {"name": "EPSG:4326"}},
    "features": [
      {
        "type": "Feature",
        "properties": {"node_id": "I-001", "source_fid": 1},
        "geometry": {"type": "Point", "coordinates": [-80.8431, 35.2271]}
      }
    ]
  },
  "model_type": "gnn",
  "node_id_field": "node_id",
  "max_search_radius": 500,
  "road_half_width_ft": 100,
  "k_neighbors": 12,
  "classification_threshold": 0.85,
  "threshold_tolerance": 0.3,
  "with_mst": true,
  "prob_weight": 0.5,
  "elev_weight": 0.0,
  "length_weight": 0.5
}
```

The 12-neighbor and 0.50/0.00/0.50 weights are the explicit DeepPipe Mobile preset. The deployed OpenAPI defaults are 3 and 0.15/0.00/0.85, but the service accepts the plugin preset because weights sum to 1.0.

The API returns HTTP 200 for a queued task:

```json
{"job_id":"abc123def456","task_id":"abc123def456","status":"queued"}
```

The plugin persists `task_id` immediately. It does not automatically retry an ambiguous POST timeout.

## Poll and retrieve

The double `jobs/jobs` path is intentional.

```http
GET /api/jobs/jobs/{task_id}/status
GET /api/jobs/jobs/{task_id}/files
GET /api/jobs/jobs/{task_id}/geojson/Pipes.geojson
POST /api/jobs/jobs/{task_id}/cancel
```

Expected status shape:

```json
{
  "job_id": "abc123def456",
  "task_id": "abc123def456",
  "status": "running",
  "state": "STARTED",
  "info": {"step": "Extracting factors"}
}
```

Terminal statuses handled by the client are `succeeded`, `failed`, and `cancelled`. On success, `/files` must identify a pipe-named GeoJSON; the client will not fall back to `Structures.geojson`. The downloaded pipe FeatureCollection is returned in EPSG:4326 and is loaded with an explicit WGS84 CRS.

The backend currently writes only pipes that meet `classification_threshold`; therefore the client cannot calculate the number of below-threshold potential pipes. To match the deployed portal, the client normalizes outcomes in this order when fields are present: final `class`, `is_connect`, `prob`/`probability`/`score` compared with the submitted threshold, explicit outcome aliases, then `model_class` as a last fallback. The stable export fields are `deeppipe_outcome` and `deeppipe_color`.

## Error shapes

FastAPI schema validation (422):

```json
{"detail":[{"loc":["body","nodes"],"msg":"Field required","type":"missing"}]}
```

Business validation (400):

```json
{
  "detail": {
    "error_field": "max_search_radius",
    "message": "must be between 100 and 1500.",
    "suggestion": ""
  }
}
```

The client also handles string `detail`, queue-unavailable 503, malformed/empty responses, network failure, and timeout.

## Security and correctness blockers before production

1. The OpenAPI document declares no authentication/security scheme, and job resources are reachable without task ownership. The plugin never lists global jobs and accesses only the task ID it received, but server-side authentication and authorization are still required.
2. The current backend implementation must project coordinates before applying `max_search_radius` in feet. EPSG:4326 degree differences must not be compared directly to a feet threshold.
3. Add idempotency support (`Idempotency-Key` or `client_request_id`) before enabling safe automatic POST retries.
4. Replace the basic health check with readiness that verifies the queue, worker, models, and county factor coverage.
5. Define a stable response/error schema in OpenAPI instead of `{}` for successful job operations.

## Live PyPASS point assessment

PyPASS uses a separate origin from Prediction. The default is
`https://lab.yyworkshop.com`.

```http
POST /api/pypass/service-life
Content-Type: application/json
```

```json
{
  "latitude": 34.2104,
  "longitude": -77.8868,
  "nominal_diameter_cast_iron": 16,
  "location_id": "qfield-demo"
}
```

The response contains `location`, nullable `soil` values, fixed-material
estimates, six gauge rows, and optional `warnings`. Null pH, resistivity,
chloride, or material estimates mean unavailable coverage and must remain
unavailable in the UI; they must never be converted to zero.

PyPASS provides service-life comparison only. The plugin must not label a
material as recommended until engineering, cost, and selection criteria are
defined and implemented.

## Raster catalogs

```http
GET /api/pypass/variables
GET /api/pypass/service-life-layer/options
```

The plugin resolves root-relative `tile_url` templates against the PyPASS
origin and loads them through QGIS's XYZ/WMS provider. Soil and service-life
tile routes are used by the live frontend but are not yet documented in the
current OpenAPI document, so the catalog response is preferred over a hard-coded
template and the backend should add these routes to OpenAPI. Gauge values are
validated against each catalog material's `gauge_sizes`; an unsupported value
falls back to that material's advertised `default_gauge` and is reported in the
plugin status.

The mobile plugin does not expose a direct COG/GeoTIFF URL input. Raster review
uses the catalog's hosted XYZ templates and does not guess or construct raw
object URLs.
