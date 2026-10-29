# DeepPipe QField project schema — v0.7.0

## Project mapping and inlet identity

Any QField project with an inlet point layer and a stable unique string/integer ID field can use the plugin. Configuration requires layer selection before its field list becomes available. Changing layers clears the field choice. Confirmed mapping is device-local and keyed by exact project path; only pathless projects use a title fallback. The plugin does not rewrite or dirty the project file.

Use a text UUID, such as `inlet_uuid`, with default `uuid('WithoutBraces')`, non-null/unique constraints, and **apply default on update** disabled. Keep it unchanged after creation. Provider FIDs can change across synchronization and are not operational node IDs. A separate `node_id` can remain the readable display value.

The minimum live input is four selected points with a valid CRS and valid WGS84 transformation. Duplicate IDs block submission; duplicate coordinates produce a warning. Locally committed edits can be selected before synchronization. The 50-point template uses an editable GeoPackage with relative project paths. Its GeoJSON fixture records the starting data for validation and is not the editable map layer.

Recommended additional inlet fields include `captured_at`, `captured_by`, `survey_status`, `elevation`, and `source`.

## Optional QGIS project entries

These entries prefill team setup; no enabled flag is required. Scope: `DeepPipe`.

| Key | Type | Meaning |
|---|---|---|
| `enabled` | Boolean | Legacy compatibility only; does not gate the plugin. |
| `schema_version` | String | Optional project configuration schema, still `1.0`. |
| `inlet_layer` | String | Exact inlet layer name. |
| `node_id_field` | String | Stable unique inlet ID field. |
| `api_mode` | String | Test mode `live` or `mock`; service origins are plugin-owned. |
| `prediction_result_layer` | String | Optional production result-layer role. |
| `assessment_layer` | String | Optional production assessment-layer role. |

```xml
<properties>
  <DeepPipe>
    <schema_version type="QString">1.0</schema_version>
    <inlet_layer type="QString">Inlets</inlet_layer>
    <node_id_field type="QString">inlet_uuid</node_id_field>
    <api_mode type="QString">live</api_mode>
  </DeepPipe>
</properties>
```

Prediction is fixed to `https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/predapi`; PyPASS is fixed to `https://lab.yyworkshop.com`. They are checked through the Configuration status card, not project URL fields.

## Device-local prediction settings

Each project's service settings contain:

```json
{
  "prediction_config": {
    "workflow_type":"progressive",
    "model_type":"progressive_gnn",
    "classification_threshold":0.5,
    "progressive_config": {
      "neighbors_per_sector":2,
      "knn_k":12,
      "knn_max_distance_ft":250,
      "rounds":3,
      "use_msf":true
    }
  }
}
```

The internal fixed threshold is retained for display compatibility and is not sent in new Progressive requests. The nested settings are normalized and copied independently. Legacy GNN/MLP threshold/MST weight settings migrate to Progressive defaults.

## Saved result state, schema 2

A result record is keyed by exact project identity and retains:

| Field | Meaning |
|---|---|
| `schema_version` | `2`, independent of QGIS project-entry schema 1.0. |
| `path`, `layer_name` | Latest-result GeoJSON and managed layer name; path may be empty for a successful empty graph. |
| `job_id`, `parent_job_id` | Completed result task and its refinement parent when applicable. |
| `workflow_type` | Progressive versus historical provenance. |
| `api_base_url` | Originating backend for this result; status, downloads, cancellation, and refinement stay pinned to it. |
| `selected_count`, `threshold`, `saved_at` | Result context and save timestamp. |
| `prediction_config`, `node_id_field` | Actual original-result configuration and ID mapping. |
| `input_nodes` | Immutable original WGS84 FeatureCollection, independent of later source-layer edits or selection. |
| `candidates` | Full scored candidate FeatureCollection, including unselected pairs. |
| `observations` | Last successfully applied canonical observation snapshot. |
| `draft_observations` | Current editable snapshot; can differ from saved observations. |
| `result_summary` | Summary retained even if the final network contains zero pipes. |

Accepted pending tasks separately retain their task/project identity and originating API URL, original inputs, settings, node field, observation snapshot, and parent ID. Reopen resumes an accepted task; it never recreates a POST from a missing response. In-session undo history is not the persisted saved snapshot.

Historical state without a valid original Progressive input remains viewable/exportable and cannot enable observation refinement. It is not silently reclassified as Progressive.

## Observation schema

```json
[
  {"node_u":"uuid-a","node_v":"uuid-b","state":"connected"},
  {"node_u":"uuid-b","node_v":"uuid-c","state":"disconnected"}
]
```

Pairs are undirected and use original stable IDs. Canonical edge IDs encode the sorted pair as a JSON array string, avoiding delimiter ambiguity. Nonempty strings and integer IDs are accepted; booleans, fractional values, missing IDs, self-pairs, unknown original endpoints, and contradictory duplicate states are rejected. Numeric `7` and text `"7"` identify the same node; `"007"` remains distinct.

Unknown is omitted, and an empty list clears all prior observations on the next update. Snapshots are complete replacements, not patches. Manually added pairs get actual line geometry from the immutable original points. Model probability can remain null/unscored until the server scores it; an effective 0/1 constraint must not be mislabeled as a model score.

These settings/snapshots and result files are local to the device. They do not automatically become synchronized survey records in QFieldCloud.

## Production result and assessment layers

For deliberately configured persistent/synchronized pipe layers, consider:

- `pipe_id`, `job_id`, `parent_job_id`, `node_u`, `node_v`, `edge_id`;
- `model_prob` (raw), `prob`/`effective_prob` (effective), `class` (final selected state), and observation state;
- `length`, `slope`, `elev_diff`, `model_version`, `created_at`;
- `deeppipe_outcome=predicted`, `deeppipe_color=#005035` for current selected pipes;
- `review_status`, `reviewed_by`, `reviewed_at`, `review_note` when an explicit review process is defined.

Assessment layers can retain `assessment_id`, `source_pipe_id`, `location_method`, coordinates, soil values, material/gauge/diameter, estimated life, analysis version, timestamp, and reviewer identity. Do not label a material recommended without implemented selection criteria.
