# DeepPipe QField project schema 1.0

## Runtime mapping

Version 0.5.13 can be used from any QField project containing a point layer and a stable unique ID field. The user chooses the layer and field in **Configuration**, confirms them once, and the plugin stores that mapping in device-local settings keyed by the exact project path and layer ID. **Pipeline Prediction** automatically uses that configured layer. A title key is used only for a genuinely pathless project; two same-title project files do not share configuration. The plugin does not modify or dirty the QGIS project.

Prediction and PyPASS origins are built into the plugin. **Configuration** exposes a service-status card that checks both endpoints; users do not enter or persist API origins, and direct COG selection is not part of the mobile workflow. Prediction settings are stored locally per exact project alongside the mapping.

For multiple users and offline synchronization, the recommended key is a text UUID field (for example `inlet_uuid`) with default expression `uuid('WithoutBraces')`, “apply default on update” disabled, and non-null/unique constraints. Do not use a provider FID as the operational inlet identity.

## Optional project custom entries

These entries preconfigure a team project but are no longer required for eligibility. A user can override the mapping locally on a device.

Scope: `DeepPipe`

| Key | Type | Required | Meaning |
|---|---|---:|---|
| `enabled` | Boolean | Legacy | Read for backward compatibility only; it no longer gates the plugin. |
| `schema_version` | String | No | Configuration schema; current value `1.0`. |
| `inlet_layer` | String | No | Exact layer name used as a setup default. |
| `node_id_field` | String | No | Stable unique string/integer identifier used as a setup default. |
| `prediction_result_layer` | String | Production | Persistent predicted-pipe layer role. |
| `assessment_layer` | String | Production | Persistent assessment layer role. |
| `api_mode` | String | No | Optional test-project default: `live` or `mock`. Service origins remain plugin-owned. |

Example project XML:

```xml
<properties>
  <DeepPipe>
    <enabled type="bool">true</enabled>
    <schema_version type="QString">1.0</schema_version>
    <inlet_layer type="QString">Inlets</inlet_layer>
    <node_id_field type="QString">inlet_uuid</node_id_field>
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
| `inlet_uuid` | Text | Recommended stable DeepPipe inlet ID for multi-user/offline collection. |
| `node_id` | Text | Optional human-readable display or legacy ID. |
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
- `deeppipe_outcome`: predicted / potential
- `deeppipe_color`: normalized display-color hint
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
