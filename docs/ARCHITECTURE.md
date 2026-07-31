# Architecture

## Decision

DeepPipe Mobile is one **app-wide QField plugin** with project-scoped configuration. The plugin supplies a consistent workflow across cities; each QGIS/QField project identifies its own inlet, pipe-result, assessment, and reference layers.

Official references:

- [QField plugin types and installation](https://docs.qfield.org/how-to/advanced-how-tos/plugins/)
- [QField plugin API](https://api.qfield.org/)
- [Official app-wide plugin template](https://github.com/opengisch/qfield-template-plugin)

## Runtime boundaries

```text
QField project
  ├─ editable inlet layer
  ├─ project custom properties
  └─ project styles / future persistent result layers
          │
          ▼
DeepPipe app-wide plugin
  ├─ touch-first drawer
  ├─ map tap selection handler
  ├─ selection snapshot + validation
  ├─ prediction / assessment state
  └─ transport boundary
          │
          ├─ v0.2 live Prediction client + mock fallback
          └─ mock Assessment client
                         │
                         ▼
                DeepPipe / PyPASS APIs
```

The plugin never embeds the existing React/Leaflet portal. QField remains the sole map canvas, selection interface, GNSS source, and project/layer manager.

## Mobile Prediction state

1. Project is inspected for `DeepPipe` custom entries.
2. Inlet layer and node-ID field are resolved.
3. User starts the explicit inlet-selection mode.
4. Each map tap finds a point within a 16-pixel rectangle, toggles it in the plugin snapshot, and mirrors the snapshot to QGIS selection highlighting.
5. The snapshot is validated for count, node-ID validity/uniqueness, and geometry.
6. Live mode transforms the snapshot to EPSG:4326 GeoJSON and submits it through QField's HTTP client; mock mode creates a deterministic local preview.
7. Live mode persists the task ID, polls with network backoff/resume, then retrieves only the pipe-named GeoJSON.
8. Live GeoJSON becomes a WGS84 memory layer; mock GeoJSON remains in the inlet-layer CRS.

The selection handler is active only during the explicit map-selection state, is throttled to avoid rapid-tap re-entry, closes every feature iterator, and is deregistered when the plugin unloads.

## Mobile Assessment state

The prototype accepts either a map point or active GNSS fix. It then shows deterministic soil and material cards to test the interface. Future pipe selection will use the selected pipe's midpoint because the current PyPASS endpoint is point-based; the UI must label that sampling method explicitly.

## Persistence plan

The v0.2 task ID is retained while a job is active, but the result is still an intentionally ephemeral memory layer. Production projects should pre-create GeoPackage layers for:

- `deeppipe_predicted_pipes`
- `deeppipe_predicted_structures`
- `deeppipe_assessments`

Those layers should own schema, styles, offline-editing policy, QFieldCloud synchronization, and review fields. Job IDs and retry state belong in app settings keyed by project ID; API tokens must use a secure authentication mechanism and must not be stored in the plugin ZIP or ordinary project properties.
