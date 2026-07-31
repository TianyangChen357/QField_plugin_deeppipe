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
  ├─ optional project defaults
  └─ project styles / future persistent result layers
          │
          ▼
DeepPipe app-wide plugin
  ├─ touch-first drawer
  ├─ tap / box / visible-area selection
  ├─ device-local per-project mapping
  ├─ selection snapshot + validation
  ├─ prediction / assessment state
  └─ transport boundary
          │
          ├─ v0.3 live Prediction client + mock fallback
          └─ mock Assessment client
                         │
                         ▼
                DeepPipe / PyPASS APIs
```

The plugin never embeds the existing React/Leaflet portal. QField remains the sole map canvas, selection interface, GNSS source, and project/layer manager.

## Mobile Prediction state

1. Point layers are discovered in any open project. A saved device mapping or optional `DeepPipe` project entries are used when valid; otherwise the user confirms the inlet layer and ID field once.
2. Layer mappings are keyed primarily by project file path and layer ID, with project title/layer name used only as recovery fallbacks.
3. User starts the explicit inlet-selection mode.
4. The drawer closes. **Tap** toggles the nearest inlet in a 16-pixel search area, **Box** adds all inlets inside a dragged rectangle, and **Visible** adds all inlets in the current map view. Each action mirrors the batch snapshot to QGIS selection highlighting once.
5. The snapshot is validated for count, node-ID validity/uniqueness, and geometry.
6. Live mode transforms the snapshot to EPSG:4326 GeoJSON and submits it through QField's HTTP client; mock mode creates a deterministic local preview.
7. Live mode persists the task ID, polls with network backoff/resume, then retrieves only the pipe-named GeoJSON.
8. Live GeoJSON becomes a WGS84 memory layer; mock GeoJSON remains in the inlet-layer CRS.

The selection handler is explicitly obtained from QField by object name, is active only during the map-selection state, is throttled to avoid rapid-tap re-entry, closes every feature iterator, and is deregistered when the plugin unloads. Box mode intentionally captures drag gestures until the user switches back to Tap mode.

## Mobile Assessment state

The prototype accepts either a map point or active GNSS fix. It then shows deterministic soil and material cards to test the interface. Future pipe selection will use the selected pipe's midpoint because the current PyPASS endpoint is point-based; the UI must label that sampling method explicitly.

## Persistence plan

The v0.3 task ID and device-local project mapping are retained in app settings, but the result is still an intentionally ephemeral memory layer. Phone-local mapping does not synchronize to other devices; team-wide defaults should be authored in the QGIS project. Production projects should pre-create GeoPackage layers for:

- `deeppipe_predicted_pipes`
- `deeppipe_predicted_structures`
- `deeppipe_assessments`

Those layers should own schema, styles, offline-editing policy, QFieldCloud synchronization, and review fields. Job IDs and retry state belong in app settings keyed by project ID; API tokens must use a secure authentication mechanism and must not be stored in the plugin ZIP or ordinary project properties.
