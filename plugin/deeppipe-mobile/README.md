# DeepPipe Mobile QField plugin — v0.7.0

This app-wide plugin adds Progressive GNN pipe prediction and PyPASS service-life assessment to the QField map.

## Install and configure

In **Settings → Plugins → Install plugin from URL**, enter:

```text
https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/mobile/deeppipe-mobile-latest.zip
```

The current campus server requires network reachability and uses a self-signed certificate; QField needs device certificate trust or a trusted deployment proxy. A browser connection alone does not establish that QField can reach it.

Enable **DeepPipe Mobile**, open a project, and tap its toolbar button. In **Configuration**, choose the inlet point layer, choose its stable unique string/integer ID field, then tap **Use this project setup**. The field chooser lists only the selected layer's fields; changing layers clears the prior choice. Mapping and settings are saved for the exact project on this device.

Use a text UUID for offline/team collection: default `uuid('WithoutBraces')`, non-null/unique constraints, and **apply default on update** disabled. Never regenerate IDs during a prediction or use provider FIDs as the stable operational key. Optional project entries can prefill `DeepPipe/inlet_layer`, `DeepPipe/node_id_field`, and `DeepPipe/api_mode` (`live` or `mock`); ordinary projects need no special enabled flag.

## Progressive Prediction

1. In **Pipeline Prediction**, choose **Select inlets on map**.
2. **Tap** toggles individual inlets, **Box** adds a dragged group, and **Visible** adds all inlets in the current view. Tap **Done** after selecting at least four valid points.
3. Tap **Predict pipes**, or expand **Specify prediction settings (optional)** first.

| Setting | Default | Allowed |
|---|---:|---|
| Neighbors per direction | 2 | 1–8, across four fixed direction sectors |
| KNN neighbors | 12 | 1–50 |
| KNN maximum distance | 250 ft | 1–5000 ft, US survey feet |
| Progressive GNN rounds | 3 | 1–10 |
| Maximum spanning forest | On | On/off |

Candidate generation also uses Delaunay. The distance setting limits KNN candidates; it is not a universal distance cutoff for every candidate source. New predictions do not submit the earlier classification threshold, MST weights, or model-type selection.

Selected points are transformed to WGS84 and submitted once. The plugin stores the accepted task ID, polls its status, downloads scored candidates and final pipes, and replaces one latest result layer after success. Green pipes are final `class=1` selections, including confirmed low-model-score connections. The table and map action allow row-to-pipe zoom/highlight; another GeoJSON copy and the complete server ZIP can be downloaded.

## Field observations

After a Progressive result:

- **Review candidate connections** includes selected and unselected scored pairs. Choose **Connected**, **Not connected**, or **Unknown**.
- **Add confirmed connection on map** lets you pick two original input inlets, including a pair the model did not propose. Finish connection selection to return to normal map interaction.
- **Undo**, **Reset draft**, and **Clear all observations** revise the current snapshot.
- **Update prediction from observations** creates a child prediction with every current observation. Clearing the list and updating also clears previous hard constraints.

Blue lines show confirmations and red dashed lines show rejections while editing/updating. On successful update, the final selected network is green and the temporary observation overlay closes. A busy animation and job messages appear while waiting. Failed/cancelled updates preserve the parent network and draft.

Connected pairs become hard 1 constraints, disconnected pairs hard 0 constraints, and unknown pairs are omitted. Model scores are retained separately. The server validates contradictory/crossing observations and other network constraints; a feasible connected network is not guaranteed for every input. Updates retain the parent's immutable input and configuration. To use new points, changed inlet coordinates/IDs, or changed configuration, submit a fresh prediction.

Previous-version results remain viewable and exportable. They lack the required original Progressive input snapshot, so observations become available after a fresh Progressive prediction. Accepted jobs remain pinned to their originating API URL and resume on reopening the same project; a POST with an ambiguous response is never automatically retried.

## Service Life Assessment

- **Point-based query:** pick a map point or use GNSS to run PyPASS and view nullable soil values and material comparisons. Gauge-dependent point estimates use the documented gauge 16.
- **Raster-based query:** choose material, applicable gauge, and minimum service life. A hosted XYZ layer replaces the previous managed raster. Transparent pixels mean no coverage or below-threshold life.

These workflows are unchanged. PyPASS is a comparison tool, not a material recommendation. Direct COG/GeoTIFF URL selection is not exposed.

**Configuration → Check API status** checks the built-in Prediction and PyPASS endpoints. Mock mode supports local preview only. Latest-result GeoJSON and per-project settings are device-local; QFieldCloud synchronization of results/observations is not automatic.

See `docs/TESTING.md` in the source/debugging bundle for automated coverage and physical-device smoke steps. Native Qt tests and mocked-host runtime tests do not replace testing in QField on Android and iOS.
