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
  └─ plugin-managed latest-result GeoJSON
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
          ├─ v0.6.0 live Prediction client + mock fallback
          ├─ live PyPASS point-assessment client
          └─ hosted PyPASS XYZ raster loader
                         │
                         ▼
                DeepPipe / PyPASS APIs
```

The plugin never embeds the existing React/Leaflet portal. QField remains the sole map canvas, selection interface, GNSS source, and project/layer manager.

## Mobile Prediction state

1. Point layers are discovered in any open project. A valid saved device mapping or optional exact `DeepPipe` project entries can prefill Configuration. Otherwise the inlet layer begins unselected; only after the user chooses it does the plugin expose that layer's fields. Changing layers clears the prior ID field, including same-named fields such as `id`. **Pipeline Prediction** consumes the confirmed mapping directly and does not present a second layer chooser.
2. Saved mappings and prediction settings are keyed by the exact project file path; each mapping also retains its selected layer ID. A project title is used only when the project truly has no path; different same-title project files never share state.
3. User starts the explicit inlet-selection mode.
4. The drawer closes. **Tap** toggles the nearest inlet in a 16-pixel search area, **Box** adds all inlets inside a dragged rectangle, and **Visible** adds all inlets in the current map view. Each action mirrors the batch snapshot to QGIS selection highlighting once.
5. The snapshot is validated for count, node-ID validity/uniqueness, and geometry.
6. Live mode transforms the snapshot to EPSG:4326 GeoJSON and submits it through QField's HTTP client; mock mode creates a deterministic local preview.
7. Live mode persists the task ID, polls with network backoff/resume, then retrieves only the pipe-named GeoJSON.
8. The backend's threshold-qualified GNN-positive features are normalized using final MST `class`: `class=1` becomes `predicted`, while `class=0` becomes `potential`. Below-threshold or model-negative records are excluded.
9. The two outcomes are written into one deterministic latest-result GeoJSON in the project home folder. The prior managed result layer is detached before overwrite, one OGR layer named `DeepPipe Prediction Results` is added, and its path plus job metadata are stored per project. Project reopen reloads that file automatically; a later successful prediction replaces it.
10. Two non-interactive `MULTILINESTRING` map geometry overlays render Predicted in Charlotte Green and Potential in yellow. Their visibility follows whether the single OGR result layer is present in `mapSettings.layers`, so the QField legend switch controls the colored geometry even though app-wide QML cannot mutate a categorized renderer. The native thin-line renderer remains visible beneath them as a fail-safe.
11. The full-field attribute table is rebuilt from the persisted layer. A map-actions toolbar icon opens it without reopening the main drawer; tapping a row selects its feature, zooms to its reprojected bounding box, and highlights it. The completed task ID also supplies the server ZIP download URL.

The normalized export fields include `deeppipe_outcome` and `deeppipe_color`
(`predicted`/`#005035` and `potential`/`#F4C430`). QField 4.2 does not expose
vector-renderer mutation through its app-wide QML plugin API, so exact mobile
colors are drawn as map overlays while a single native-visible OGR layer owns legend
visibility, selection, and attributes. A production project can instead
apply rule-based colors in pre-created persistent result layers.

The selection handler is obtained lazily from QField only when a map-selection state starts, is throttled to avoid rapid-tap re-entry, closes every feature iterator, and is deregistered as soon as selection finishes or is cancelled. It is not registered during plugin startup or idle map use, so it cannot capture first-install one-finger panning. Tap, Box, and Visible convert screen bounds to a `QgsRectangle` using `QgsPoint` values from `GeometryUtils.point()` before querying the configured layer. Box mode intentionally captures drag gestures until the user switches back to Tap mode.

## Mobile Assessment state

Service Life Assessment exposes two independent workflows. **Point-based query** accepts a map point or active GNSS fix, submits WGS84 coordinates and the API's internal cast-iron reference size to the live PyPASS point endpoint, and immediately shows nullable soil properties plus fixed- and gauge-material service-life estimates at the explicit point-query gauge. **Raster-based query** accepts material, applicable gauge, and minimum service life before adding one hosted XYZ layer. Changing raster settings does not clear a point result. Missing coverage remains unavailable; it is never converted to zero. PyPASS results are comparisons, not automatic material recommendations.

The raster workflow retrieves the current XYZ service-life template from the live PyPASS catalog. For the current public proxy, the plugin preserves an encoded terminal dot in `.png` tile paths so requests reach FastAPI, double-encoding it inside the QGIS data-source URI. Direct COG/GeoTIFF selection is intentionally not exposed. Future pipe selection can use a selected pipe midpoint, but that method must be explicitly recorded as `pipe_midpoint` with the source pipe ID.

## Persistence plan

The v0.6.0 task ID, device-local project mapping, prediction settings, and latest-result path are retained in app settings. The latest-result GeoJSON is stored in the project home folder and its layer is restored automatically, but it is not inserted into or used to rewrite the `.qgs`/`.qgz` file. The result is not automatically synchronized by QFieldCloud. Phone-local mapping does not synchronize to other devices; team-wide inlet defaults should be authored in the QGIS project. Production projects that require synchronization and review should pre-create GeoPackage layers for:

- `deeppipe_predicted_pipes`
- `deeppipe_predicted_structures`
- `deeppipe_assessments`

Those layers should own schema, styles, offline-editing policy, QFieldCloud synchronization, and review fields. Job IDs and retry state belong in app settings keyed by project ID; API tokens must use a secure authentication mechanism and must not be stored in the plugin ZIP or ordinary project properties.
