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
          ├─ v0.5.13 live Prediction client + mock fallback
          ├─ live PyPASS point-assessment client
          └─ hosted PyPASS XYZ raster loader
                         │
                         ▼
                DeepPipe / PyPASS APIs
```

The plugin never embeds the existing React/Leaflet portal. QField remains the sole map canvas, selection interface, GNSS source, and project/layer manager.

## Mobile Prediction state

1. Point layers are discovered in any open project. A saved device mapping or optional `DeepPipe` project entries are used when valid; otherwise the user confirms the inlet layer and ID field once in **Configuration**. **Pipeline Prediction** consumes this mapping directly and does not present a second layer chooser.
2. Saved mappings and service/raster settings are keyed by the exact project file path and layer ID. A project title is used only when the project truly has no path; different same-title project files never share state.
3. User starts the explicit inlet-selection mode.
4. The drawer closes. **Tap** toggles the nearest inlet in a 16-pixel search area, **Box** adds all inlets inside a dragged rectangle, and **Visible** adds all inlets in the current map view. Each action mirrors the batch snapshot to QGIS selection highlighting once.
5. The snapshot is validated for count, node-ID validity/uniqueness, and geometry.
6. Live mode transforms the snapshot to EPSG:4326 GeoJSON and submits it through QField's HTTP client; mock mode creates a deterministic local preview.
7. Live mode persists the task ID, polls with network backoff/resume, then retrieves only the pipe-named GeoJSON.
8. The backend's threshold-qualified GNN-positive features are normalized using final MST `class`: `class=1` becomes `predicted`, while `class=0` becomes `potential`. Below-threshold or model-negative records are excluded. Each non-empty outcome becomes its own attribute-bearing memory layer.
9. Two non-interactive map geometry overlays render Predicted in Charlotte Green and Potential in yellow. This provides exact colors without mutating QGIS renderers through the app-wide QML boundary.
10. The combined decorated GeoJSON and a dynamic full-field attribute table remain in plugin state. On export, a short-lived memory layer is created, written under the project or device documents folder, and removed immediately. The completed task ID also supplies the server ZIP download URL.

The normalized export fields include `deeppipe_outcome` and `deeppipe_color`
(`predicted`/`#005035` and `potential`/`#F4C430`). QField 4.2 does not expose
vector-renderer mutation through its app-wide QML plugin API, so exact mobile
colors are drawn as map overlays while the separate memory layers retain all
attributes and remain available to identify. A production project can instead
apply rule-based colors in pre-created persistent result layers.

The selection handler is explicitly obtained from QField by object name, is active only during the map-selection state, is throttled to avoid rapid-tap re-entry, closes every feature iterator, and is deregistered when the plugin unloads. Tap, Box, and Visible convert screen bounds to a `QgsRectangle` using `QgsPoint` values from `GeometryUtils.point()` before querying the configured layer. Box mode intentionally captures drag gestures until the user switches back to Tap mode.

## Mobile Assessment state

The plugin accepts either a map point or active GNSS fix, submits WGS84 coordinates and the API's internal cast-iron reference size to the live PyPASS point endpoint, and shows nullable soil properties plus fixed- and gauge-material service-life estimates. The user chooses a material first; the gauge selector is enabled only for gauge-dependent materials. Missing raster coverage is displayed as unavailable with the server warning; it is never converted to zero. PyPASS results are comparisons, not automatic material recommendations.

The raster workflow retrieves current XYZ templates from the live PyPASS catalog before adding pH, resistivity, chloride, or thresholded service-life layers. Direct COG/GeoTIFF selection is intentionally not exposed. Future pipe selection can use a selected pipe midpoint, but that method must be explicitly recorded as `pipe_midpoint` with the source pipe ID.

## Persistence plan

The v0.5.13 task ID, device-local project mapping, and prediction settings are retained in app settings, but map result layers are still intentionally ephemeral. Users can save a combined GeoJSON result or download the server job ZIP; neither is automatically synchronized by QFieldCloud. Phone-local mapping does not synchronize to other devices; team-wide inlet defaults should be authored in the QGIS project. Production projects should pre-create GeoPackage layers for:

- `deeppipe_predicted_pipes`
- `deeppipe_predicted_structures`
- `deeppipe_assessments`

Those layers should own schema, styles, offline-editing policy, QFieldCloud synchronization, and review fields. Job IDs and retry state belong in app settings keyed by project ID; API tokens must use a secure authentication mechanism and must not be stored in the plugin ZIP or ordinary project properties.
