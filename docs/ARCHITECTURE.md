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
          ├─ v0.4 live Prediction client + mock fallback
          ├─ live PyPASS point-assessment client
          └─ hosted XYZ / user-supplied COG raster loader
                         │
                         ▼
                DeepPipe / PyPASS APIs
```

The plugin never embeds the existing React/Leaflet portal. QField remains the sole map canvas, selection interface, GNSS source, and project/layer manager.

## Mobile Prediction state

1. Point layers are discovered in any open project. A saved device mapping or optional `DeepPipe` project entries are used when valid; otherwise the user confirms the inlet layer and ID field once.
2. Saved mappings and service/raster settings are keyed by the exact project file path and layer ID. A project title is used only when the project truly has no path; different same-title project files never share state.
3. User starts the explicit inlet-selection mode.
4. The drawer closes. **Tap** toggles the nearest inlet in a 16-pixel search area, **Box** adds all inlets inside a dragged rectangle, and **Visible** adds all inlets in the current map view. Each action mirrors the batch snapshot to QGIS selection highlighting once.
5. The snapshot is validated for count, node-ID validity/uniqueness, and geometry.
6. Live mode transforms the snapshot to EPSG:4326 GeoJSON and submits it through QField's HTTP client; mock mode creates a deterministic local preview.
7. Live mode persists the task ID, polls with network backoff/resume, then retrieves only the pipe-named GeoJSON.
8. Returned features are normalized into `predicted`, `potential`, or `unknown` outcomes. Each non-empty outcome becomes its own memory layer; potential and unknown layers use reduced opacity. Live GeoJSON uses WGS84 and mock GeoJSON remains in the inlet-layer CRS.
9. The combined decorated GeoJSON remains in plugin state. On export, a short-lived memory layer is created, written under the project or device documents folder, and removed immediately.

The normalized export fields include `deeppipe_outcome` and `deeppipe_color`
(`predicted`/green, `potential`/orange, and `unknown`/gray). QField 4.2 does not
expose categorized-renderer mutation through its QML plugin API, so the generic
app-wide fallback separates outcomes into layers and uses opacity. A production
project can apply exact rule-based colors in pre-created result layers using
the normalized fields.

The selection handler is explicitly obtained from QField by object name, is active only during the map-selection state, is throttled to avoid rapid-tap re-entry, closes every feature iterator, and is deregistered when the plugin unloads. Box mode intentionally captures drag gestures until the user switches back to Tap mode.

## Mobile Assessment state

The plugin accepts either a map point or active GNSS fix, submits WGS84 coordinates and cast-iron nominal diameter to the live PyPASS point endpoint, and shows nullable soil properties plus fixed- and gauge-material service-life estimates. Missing raster coverage is displayed as unavailable with the server warning; it is never converted to zero. PyPASS results are comparisons, not automatic material recommendations.

The raster workflow retrieves current XYZ templates from the live PyPASS catalog before adding pH, resistivity, chloride, or thresholded service-life layers. It also accepts a direct public HTTPS COG/GeoTIFF URL supplied by the user and opens it through GDAL `/vsicurl/`. No raw COG URL is present in the current public catalog, so none is guessed or embedded. Future pipe selection can use a selected pipe midpoint, but that method must be explicitly recorded as `pipe_midpoint` with the source pipe ID.

## Persistence plan

The v0.4 task ID and device-local project mapping are retained in app settings, but map result layers are still intentionally ephemeral. Users can save a combined GeoJSON result; the export is not automatically synchronized by QFieldCloud. Phone-local mapping does not synchronize to other devices; team-wide defaults should be authored in the QGIS project. Production projects should pre-create GeoPackage layers for:

- `deeppipe_predicted_pipes`
- `deeppipe_predicted_structures`
- `deeppipe_assessments`

Those layers should own schema, styles, offline-editing policy, QFieldCloud synchronization, and review fields. Job IDs and retry state belong in app settings keyed by project ID; API tokens must use a secure authentication mechanism and must not be stored in the plugin ZIP or ordinary project properties.
