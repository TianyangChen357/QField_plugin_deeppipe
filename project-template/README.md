# DeepPipe Raleigh 50-Node Template — v1.0.0

This is an editable QField project containing the **same 50 Raleigh inlet locations offered by the DeepPipe Web Portal**. Their original inventory IDs are preserved. Use it to test DeepPipe Mobile, or copy it as the starting project for collecting more inlets.

The points come from `Raleigh.gpkg / Inlets`. They are real inventory locations, not verified pipe connections. No prefilled connectivity observations or ground-truth pipe labels are included. Green point symbols identify inlets, not confirmed pipes.

## Open the project

Install and enable **DeepPipe Mobile v0.7.0 or later** separately. The project package does not install the plugin.

Use the **Template project** QR/action on the Portal's **DeepPipe Mobile** page, confirm the import in QField, and open the imported `DeepPipe_Mobile_Demo.qgs`. The direct project ZIP is:

```text
https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/mobile/deeppipe-qfield-template-latest.zip
```

For a manual import, download and extract the ZIP to a writable folder, transfer/import the complete folder into QField, and open `DeepPipe_Mobile_Demo.qgs`. Keep the project beside its `data` directory. Do not open it inside a ZIP or a read-only download preview.

The campus server requires campus-network/VPN access and trust for its self-signed certificate on the device. Editing can work offline after import. Downloading the package, the optional OpenStreetMap basemap, and live prediction need network access. OpenStreetMap tiles are not bundled; attribution: [© OpenStreetMap contributors](https://www.openstreetmap.org/copyright).

## Test the plugin

1. Open the project and DeepPipe Mobile. Its mapping is already **Inlets → inlet_uuid**; check it under **Configuration** and check API status.
2. In **Pipeline Prediction**, choose **Select inlets on map**. Use **Tap**, **Box**, or **Visible**, then **Done**. Select at least four points; selecting the complete sample uses all 50.
3. Predict with the defaults: two neighbors per directional sector, KNN 12 within 250 ft, three Progressive GNN rounds, and maximum spanning forest enabled.
4. Review candidate pairs as **Connected**, **Not connected**, or **Unknown**, or confirm a missing pair by selecting two original input inlets on the map.
5. Select **Update prediction from observations**. The complete snapshot is sent for a new prediction; successful results become the green pipe network. Try undo, reset, or clear observations and update again.

Prediction uses `https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/predapi`; PyPASS uses `https://lab.yyworkshop.com`. Endpoints belong to the installed plugin, not the project's attributes. Constraints can be incompatible, and MSF does not guarantee one connected network.

## Edit or add inlets

The **Inlets** layer is a writable GeoPackage (`data/inlets.gpkg`). Activate that layer in QField and use its editing/digitizing controls to move points, change their label/status/notes, delete points, or add more points. Save edits before selecting inputs for another live prediction.

| Form field | Behavior |
|---|---|
| **Inlet label** (`node_id`) | Editable readable label. Sample labels match the Raleigh inventory ID; new points get a `Field-…` default that can be changed. |
| **Original Raleigh ID** (`source_id`) | Read-only source reference; new field points have no invented inventory ID. |
| **Stable ID (automatic)** (`inlet_uuid`) | Read-only UUID generated once for new features. Hard unique/non-null constraints prevent missing or duplicate prediction identities. Geometry/attribute edits do not regenerate it. |
| **Collection status** (`status`) | Sample, New, Surveyed, or Needs review. This does not set a pipe observation. |
| **Field notes** (`notes`) | Editable multiline notes. |
| **Created on device** (`captured_at`) | Filled for new features; original sample timestamps remain unknown. |
| **Data source** (`source`) | Read-only provenance; new points use `qfield`. |

**After adding, deleting, or moving input points, start a new prediction with the desired point selection.** Updating from observations retains that prediction's original nodes, coordinates, and configuration.

To reuse this as a field template, make a separate writable copy of the complete folder first. Keep or remove the sample inlets, then collect new features. Save that copy at its own project location; importing the original template again should not replace collected field data. Files, plugin settings, and observations do not automatically synchronize between devices.

## Files and validation

- `DeepPipe_Mobile_Demo.qgs`: portable project with relative paths, EPSG:3857 map view, labelled inlets, and optional online OpenStreetMap.
- `data/inlets.gpkg`: editable EPSG:4326 point layer used by the project.
- `data/inlets.geojson`: immutable WGS84 sample/provenance fixture; it is not a second map layer and does not change when the GeoPackage is edited.
- `template.json`: template version, source, mapping, and Progressive defaults.

Native PyQGIS tests load an isolated copy, compare all 50 coordinates/source IDs, add points with automatic UUIDs, edit geometry and attributes, delete points, save, and reopen. They do not replace physical Android/iOS testing of camera scanning, OS import handling, and device storage permissions.

Rebuild with QGIS 3.40+ Python from the repository root:

```bash
python3 scripts/build_project_template.py
python3 tests/test_project_template.py
```

The builder normally uses the committed sample fixture. To rebuild from the Portal's original WGS84 sample, pass `--source /path/to/raleigh_50_nodes.geojson`. Set `DEEPPIPE_PORTAL_SAMPLE` to that path for an additional exact cross-repository comparison in the native tests.
