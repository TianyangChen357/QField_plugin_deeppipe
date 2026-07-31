# DeepPipe QField project schema 1.0

## Project custom entries

Scope: `DeepPipe`

| Key | Type | Required | Meaning |
|---|---|---:|---|
| `enabled` | Boolean | Yes | Enables the app-wide plugin for this project. |
| `schema_version` | String | Yes | Configuration schema; current value `1.0`. |
| `inlet_layer` | String | Yes | Exact layer name for editable inlet points. |
| `node_id_field` | String | Yes | Stable unique string/integer identifier. |
| `prediction_result_layer` | String | Production | Persistent predicted-pipe layer role. |
| `assessment_layer` | String | Production | Persistent assessment layer role. |
| `api_base_url` | String | No | Prediction endpoint base; default test value `https://lab.yyworkshop.com/predapi`. Never store secrets here. |
| `api_mode` | String | Yes | Initial Prediction mode: `live` or `mock`. The app-wide user toggle is then retained. |

Example project XML:

```xml
<properties>
  <DeepPipe>
    <enabled type="bool">true</enabled>
    <schema_version type="QString">1.0</schema_version>
    <inlet_layer type="QString">Inlets</inlet_layer>
    <node_id_field type="QString">node_id</node_id_field>
    <api_base_url type="QString">https://lab.yyworkshop.com/predapi</api_base_url>
    <api_mode type="QString">live</api_mode>
  </DeepPipe>
</properties>
```

## Inlet layer minimum contract

- Geometry: point, valid CRS.
- Node ID: non-null, unique, string or integer.
- Locally committed field edits are eligible even before cloud synchronization.
- Minimum submission: three selected points.
- Duplicate coordinates produce a warning; duplicate IDs block submission.

Recommended operational fields:

| Field | Type | Purpose |
|---|---|---|
| `node_id` | Text | Stable DeepPipe inlet ID. |
| `captured_at` | DateTime | Field collection timestamp. |
| `captured_by` | Text | Collector or device/user identity. |
| `survey_status` | Text | Draft, surveyed, needs review. |
| `elevation` | Decimal | Survey/GNSS elevation if collected. |
| `source` | Text | QField, authoritative import, legacy, etc. |

The demo uses GeoJSON for portability. Real deployments should use GeoPackage or an intentionally configured online provider.

## Production predicted-pipe fields

At minimum:

- `pipe_id`, `job_id`, `node_u`, `node_v`
- `prob`, `model_class`, `class`
- `length`, `slope`, `elev_diff`
- `model_version`, `created_at`
- `review_status`: unreviewed / accepted / rejected / needs_survey
- `reviewed_by`, `reviewed_at`, `review_note`

## Production assessment fields

At minimum:

- `assessment_id`, `source_pipe_id`, `location_method`
- `latitude`, `longitude`
- `ph`, `resistivity_ohm_cm`, `chloride`
- `material`, `gauge`, `nominal_diameter`, `estimated_life_years`
- `analysis_version`, `assessed_at`, `assessed_by`

Do not label a material “recommended” until cost and selection criteria have been defined and implemented.
