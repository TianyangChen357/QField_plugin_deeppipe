# DeepPipe Mobile v0.7.0 demo project

`DeepPipe_Mobile_Demo.qgs` contains ten **synthetic** inlet points near central Charlotte for QField interaction and controlled Prediction testing. Keep it beside `data/inlets.geojson` in the same relative structure when copying the project.

The project defaults are:

- Inlet layer: `Inlets`.
- Stable prediction ID: `inlet_uuid`; readable display ID: `node_id`.
- Optional project-entry schema: `1.0`.
- Transport: `live`; `api_mode=mock` gives local preview only.

Each inlet has a stable UUID. New features use the QGIS default `uuid('WithoutBraces')`; the UUID field is not editable and is generated only at creation. This demonstrates the intended offline/team identity pattern. Real deployments should use a GeoPackage or intentionally configured provider and test their edit/sync policy.

1. Install/enable DeepPipe Mobile and open this project.
2. In **Configuration**, confirm `Inlets` and `inlet_uuid`, then check API status.
3. In **Pipeline Prediction**, choose four or more demo inlets using Tap, Box, or Visible. Predict with the defaults: two neighbors per direction, KNN 12 within 250 ft, three rounds, maximum spanning forest on.
4. Review selected/unselected candidates. Mark a connected and a not-connected observation, or add a confirmed pair by tapping two original inlets.
5. Update from observations, then try Unknown, undo, reset draft, and clear-all/update. Confirm saved/draft state survives reopening the project.

Updates retain the original prediction's input and settings. New source coordinates/IDs, selection, or configuration require a fresh prediction. Connected/disconnected are hard constraints; incompatible constraints may be rejected and a fully connected graph is not guaranteed.

The plugin uses `https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/predapi` for Progressive Prediction and `https://lab.yyworkshop.com` for PyPASS. The current campus host needs network reachability and trusted certificate handling on the device (or a proxy with a trusted certificate). There are no project API URL fields to edit. The older public lab `/predapi` backend does not provide this Progressive workflow.

Use these synthetic points for initial live tests. Native Qt and mocked-host tests do not replace a physical Android/iOS QField smoke run; follow `docs/TESTING.md` in the source/debugging bundle.
