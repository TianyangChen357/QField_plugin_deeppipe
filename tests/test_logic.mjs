import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const logicPath = path.resolve(here, "../plugin/deeppipe-mobile/logic/DeepPipe.js");
const source = fs.readFileSync(logicPath, "utf8");
const context = vm.createContext({
  console,
  Date,
  Math,
  Number,
  String,
  Boolean,
  Array,
  Object,
  JSON,
});
vm.runInContext(source, context, { filename: logicPath });

const plain = value => JSON.parse(JSON.stringify(value));
const points = [
  { fid: 1, nodeId: "I-001", x: 0, y: 0 },
  { fid: 2, nodeId: "I-002", x: 10, y: 0 },
  { fid: 3, nodeId: "I-003", x: 10, y: 10 },
  { fid: 4, nodeId: "I-004", x: 30, y: 10 },
];
const defaults = context.predictionDefaults();
assert.deepEqual(plain(defaults), {
  workflow_type: "progressive", model_type: "progressive_gnn", classification_threshold: 0.5,
  progressive_config: {neighbors_per_sector: 2, knn_k: 12, knn_max_distance_ft: 250, rounds: 3, use_msf: true},
});
const fresh = context.predictionDefaults();
fresh.progressive_config.rounds = 9;
assert.equal(defaults.progressive_config.rounds, 3, "default settings must not share nested objects");
const normalized = context.normalizePredictionConfig({progressive_config: {
  neighbors_per_sector: 20, knn_k: 70, knn_max_distance_ft: 10000, rounds: 0, use_msf: false,
}});
assert.deepEqual(plain(normalized.progressive_config), {
  neighbors_per_sector: 8, knn_k: 50, knn_max_distance_ft: 5000, rounds: 1, use_msf: false,
});
const custom = {progressive_config: {neighbors_per_sector: 4, knn_k: 8, knn_max_distance_ft: 400, rounds: 6, use_msf: false}};
const legacy = {model_type: "mlp", max_search_radius: 1500, k_neighbors: 8, classification_threshold: 0.98, with_mst: false};
assert.deepEqual(plain(context.normalizePredictionConfig(legacy)), plain(defaults), "old settings must migrate to the new defaults");
assert.deepEqual(plain(context.normalizePredictionConfig(custom).progressive_config), custom.progressive_config);
custom.progressive_config.rounds = 4;
assert.equal(normalized.progressive_config.rounds, 1);
assert.equal(context.projectKey("/projects/a.qgs", "Same title"), "path:/projects/a.qgs");
assert.equal(context.projectKey("", "Same title"), "title:Same title");
const mappingJson = context.updateProjectMapping("{}", "/projects/a.qgs", "Same title", {
  layer_id: "layer-a", layer_name: "Inlets", node_id_field: "inlet_uuid", confirmed_at: "2026-07-31T18:00:00.000Z",
});
assert.equal(context.projectMapping(mappingJson, "/projects/a.qgs", "Same title").node_id_field, "inlet_uuid");
assert.equal(context.projectMapping(mappingJson, "/projects/moved.qgs", "Same title"), null);
assert.equal(context.projectMapping("not json", "/projects/a.qgs", "Same title"), null);
let serviceSettingsJson = context.updateProjectServiceSettings("{}", "/projects/a.qgs", "Same title", {prediction_config: custom});
serviceSettingsJson = context.updateProjectServiceSettings(serviceSettingsJson, "/projects/b.qgs", "Same title", {prediction_config: legacy});
assert.equal(context.projectServiceSettings(serviceSettingsJson, "/projects/a.qgs", "Same title").prediction_config.progressive_config.knn_k, 8);
assert.equal(context.projectServiceSettings(serviceSettingsJson, "/projects/b.qgs", "Same title").prediction_config.progressive_config.knn_k, 12);
assert.equal(context.projectServiceSettings(serviceSettingsJson, "/projects/b.qgs", "Same title").prediction_config.model_type, "progressive_gnn");
assert.equal(context.projectServiceSettings(serviceSettingsJson, "/projects/c.qgs", "Same title"), null);
const bulkRecords = Array.from({ length: 500 }, (_, index) => ({fid: index + 1, nodeId: `uuid-${index + 1}`, x: index, y: index}));
const firstBulkMerge = context.mergePointRecords(bulkRecords.slice(0, 20), bulkRecords);
assert.equal(firstBulkMerge.records.length, 500);
assert.equal(firstBulkMerge.added, 480);
assert.equal(context.mergePointRecords(firstBulkMerge.records, bulkRecords).added, 0);
assert.equal(context.validateSelectedPoints(points).ok, true);
assert.equal(context.validateSelectedPoints(points.slice(0, 3)).errors[0].code, "TOO_FEW_INLETS");
const duplicateId = points.map(point => ({...point}));
duplicateId[3].nodeId = "I-001";
assert.equal(context.validateSelectedPoints(duplicateId).errors.some(error => error.code === "DUPLICATE_NODE_ID"), true);
const geographicPoints = [
  { fid: 11, nodeId: "G-001", x: -80, y: 35, longitude: -80, latitude: 35 },
  { fid: 12, nodeId: "G-002", x: -80, y: 35.0005, longitude: -80, latitude: 35.0005 },
  { fid: 13, nodeId: "G-003", x: -80, y: 35.001, longitude: -80, latitude: 35.001 },
  { fid: 14, nodeId: "G-004", x: -80, y: 35.0015, longitude: -80, latitude: 35.0015 },
];
assert.equal(context.validateLiveSelectedPoints(geographicPoints).ok, true);
assert.equal(context.validateLiveSelectedPoints(geographicPoints.slice(0, 3)).ok, false);
assert.equal(context.validateLiveSelectedPoints(geographicPoints.map((p,i) => i === 0 ? {...p, longitude: 999} : p)).errors.some(e => e.code === "INVALID_WGS84_GEOMETRY"), true);
const liveFeatureCollection = context.featureCollectionFromPoints(geographicPoints, "node_id");
assert.equal(liveFeatureCollection.crs.properties.name, "EPSG:4326");
assert.deepEqual(plain(liveFeatureCollection.features[0].geometry.coordinates), [-80, 35]);
const request = context.buildPredictionRequest(liveFeatureCollection, "node_id", custom, {client_request_id: "abc"});
assert.deepEqual(Object.keys(request).sort(), ["model_type", "node_id_field", "nodes", "progressive_config", "workflow_type"]);
assert.equal(request.workflow_type, "progressive");
assert.equal(request.model_type, "progressive_gnn");
assert.equal(request.node_id_field, "node_id");
assert.equal(request.progressive_config.knn_max_distance_ft, 400);
request.progressive_config.rounds = 7;
assert.equal(custom.progressive_config.rounds, 4, "request must copy nested settings");
const firstPrediction = context.buildMockPrediction(points, defaults, "mock-test");
assert.equal(firstPrediction.ok, true);
assert.equal(firstPrediction.summary.predicted, 3);
assert.equal(JSON.stringify(firstPrediction), JSON.stringify(context.buildMockPrediction(points, defaults, "mock-test")));
assert.equal(firstPrediction.featureCollection.features.every(f => f.properties.analysis_mode === "mock_preview"), true);

// Observation snapshots use original undirected IDs, never feature row indices.
assert.deepEqual(plain(context.canonicalNodePair(2, "001")), {node_u: "001", node_v: "2", key: '["001","2"]'});
assert.equal(context.canonicalNodePair("A|B", "C").key === context.canonicalNodePair("A", "B|C").key, false);
assert.equal(context.canonicalNodePair("B", "A").key, context.canonicalNodePair("A", "B").key);
for (const id of [true, false, null, undefined, "", "  ", 1.5, Infinity, NaN]) {
  assert.throws(() => context.canonicalNodePair(id, "valid"));
}
assert.throws(() => context.canonicalNodePair(7, "7"), /itself/);
const confirmed = {node_u: "G-002", node_v: "G-001", state: "connected"};
const negative = {node_u: "G-003", node_v: "G-004", state: "disconnected"};
const observations = context.normalizeObservations([confirmed, confirmed, negative], liveFeatureCollection, "node_id");
assert.equal(observations.length, 2);
assert.equal(observations[0].node_u, "G-001");
assert.throws(() => context.normalizeObservations([confirmed, {...confirmed, state: "disconnected"}]), /both/);
assert.throws(() => context.normalizeObservations([{...confirmed, node_v: "missing"}], liveFeatureCollection), /unknown/);
assert.throws(() => context.normalizeObservations([{...confirmed, state: "unknown"}]), /state/);
assert.throws(() => context.normalizeObservations({observations: []}), /list/);
const originalObservations = JSON.stringify(observations);
const removed = context.setObservation(observations, "G-001", "G-002", "unknown", liveFeatureCollection);
assert.equal(removed.length, 1);
assert.equal(JSON.stringify(observations), originalObservations, "edits must preserve undo snapshots");
const restored = context.setObservation(removed, "G-001", "G-002", "connected", liveFeatureCollection);
assert.equal(context.observationsEqual(restored, observations), true);
assert.equal(context.observationState(restored, "G-004", "G-003"), "disconnected");
assert.equal(context.observationState(restored, "G-001", "G-004"), "unknown");
assert.throws(() => context.setObservation(observations, "unknown", "G-001", "unknown", liveFeatureCollection), /unknown/);
const reset = context.resetObservations(observations);
reset[0].state = "disconnected";
assert.equal(observations[0].state, "connected");
assert.deepEqual(plain(context.clearObservations()), []);
const history = [observations, removed];
const undone = context.undoObservation(history, []);
assert.deepEqual(plain(undone.observations), plain(removed));
assert.equal(undone.history.length, 1);
assert.equal(history.length, 2);
assert.deepEqual(plain(context.buildRefinementRequest([], liveFeatureCollection)), {observations: []}, "empty snapshot clears previous observations");
assert.deepEqual(plain(context.buildRefinementRequest(observations, liveFeatureCollection)).observations, plain(observations));
const observationGeometry = context.observationFeatureCollection(liveFeatureCollection, observations, "node_id");
assert.equal(observationGeometry.features.length, 2);
assert.deepEqual(plain(observationGeometry.features[0].geometry.coordinates), [[-80, 35], [-80, 35.0005]]);
assert.equal(observationGeometry.features[0].properties.observation, 1);
assert.equal(observationGeometry.features[1].properties.observation, 0);
assert.equal("model_prob" in observationGeometry.features[0].properties, false, "manual outside pairs must not invent neural scores");
const candidates = {type:"FeatureCollection", features:[{
  type:"Feature", properties:{node_u:"G-002",node_v:"G-001",class:0,model_prob:0.15},
  geometry:{type:"LineString",coordinates:[[-80,35.0005],[-80,35]]},
}]};
const reviewRows = context.observationRows(candidates, observations);
assert.equal(reviewRows.length, 2, "outside observed pairs appear beside scored candidates");
assert.equal(reviewRows[0].model_prob, 0.15);
assert.equal(reviewRows[0].state, "connected");
assert.equal(reviewRows[0].selected, false);
assert.equal(reviewRows[1].model_prob, null);
const extended = context.mergeObservationCandidates(candidates, liveFeatureCollection, observations, "node_id");
assert.equal(extended.features.length, 2);
assert.equal(candidates.features.length, 1);
assert.deepEqual(plain(extended.features[1].geometry.coordinates), [[-80,35.001],[-80,35.0015]]);
const outside = context.createObservationEdge(liveFeatureCollection, "G-001", "G-004", "connected", "node_id");
assert.deepEqual(plain(outside.geometry.coordinates), [[-80,35],[-80,35.0015]]);
assert.throws(() => context.createObservationEdge(liveFeatureCollection, "missing", "G-004", "connected", "node_id"), /unknown/);

// Project-scoped persistence includes immutable inputs, candidates, and saved/draft snapshots.
let resultStatesJson = context.updatePredictionResultState("{}", "/projects/a.qgs", "Same title", {
  path:"/projects/result-a.geojson", job_id:"job-a", parent_job_id:"parent-a", selected_count:4,
  api_base_url:"https://prediction.example.org/current/",
  prediction_config:custom, input_nodes:liveFeatureCollection, candidates,
  observations, draft_observations:removed, node_id_field:"node_id", workflow_type:"progressive",
});
const state = context.predictionResultState(resultStatesJson, "/projects/a.qgs", "Same title");
assert.equal(state.job_id, "job-a");
assert.equal(state.parent_job_id, "parent-a");
assert.equal(state.api_base_url, "https://prediction.example.org/current");
assert.equal(state.workflow_type, "progressive");
assert.equal(state.prediction_config.progressive_config.knn_k, 8);
assert.equal(state.input_nodes.features.length, 4);
assert.equal(state.candidates.features[0].properties.model_prob, 0.15);
assert.equal(state.observations.length, 2);
assert.equal(state.draft_observations.length, 1);
assert.equal(context.predictionResultState(resultStatesJson, "/projects/b.qgs", "Same title"), null);
resultStatesJson = context.updatePredictionResultState(resultStatesJson, "/projects/b.qgs", "Same title", {
  path:"",job_id:"empty-job",input_nodes:liveFeatureCollection,observations:[],draft_observations:[],
  result_summary:{predicted:0,selectedInlets:4},
});
assert.equal(context.predictionResultState(resultStatesJson, "/projects/b.qgs", "Same title").job_id, "empty-job");
assert.equal(context.predictionResultState(resultStatesJson, "/projects/b.qgs", "Same title").result_summary.predicted, 0);
assert.equal(context.predictionResultState(resultStatesJson, "/projects/a.qgs", "Same title").job_id, "job-a");
const historical = context.updatePredictionResultState("{}", "/projects/old.qgs", "Old", {path:"old.geojson",job_id:"legacy-job"});
assert.equal(context.predictionResultState(historical, "/projects/old.qgs", "Old").workflow_type, "legacy");
resultStatesJson = context.updatePredictionResultState(resultStatesJson, "/projects/a.qgs", "Same title", null);
assert.equal(context.predictionResultState(resultStatesJson, "/projects/a.qgs", "Same title"), null);
assert.equal(context.predictionResultState(resultStatesJson, "/projects/b.qgs", "Same title").job_id, "empty-job");

assert.equal(context.normalizeApiBaseUrl("https://lab.yyworkshop.com/predapi/"), "https://lab.yyworkshop.com/predapi");
assert.equal(context.normalizeApiBaseUrl("lab.yyworkshop.com"), "");
assert.equal(
  context.apiUrl("https://lab.yyworkshop.com/predapi/", "/health"),
  "https://lab.yyworkshop.com/predapi/health",
);
assert.equal(
  context.resolveCatalogUrl("https://lab.yyworkshop.com/deeppipe-pass", "/api/pypass/tiles/ph/{z}/{x}/{y}.png"),
  "https://lab.yyworkshop.com/api/pypass/tiles/ph/{z}/{x}/{y}.png",
);
assert.equal(
  context.apiErrorMessage({ detail: [{ loc: ["body", "nodes"], msg: "Field required" }] }, 422, ""),
  "nodes: Field required",
);
assert.equal(
  context.apiErrorMessage({ detail: { message: "CRS missing.", suggestion: "Add EPSG:4326 definition." } }, 400, ""),
  "CRS missing. Add EPSG:4326 definition.",
);
assert.equal(context.choosePipeResultFilename(["Structures.geojson", "Pipes.geojson", "log.txt"]), "Pipes.geojson");
assert.equal(context.choosePipeResultFilename([{ name: "Pipes.geojson" }]), "Pipes.geojson");
assert.equal(
  context.choosePipeResultFilename([{ url: "https://example.org/jobs/7/Pipes.geojson?token=test" }]),
  "Pipes.geojson",
);
assert.equal(context.choosePipeResultFilename(["Structures.geojson", "log.txt"]), "");

const livePipeResult = {
  type: "FeatureCollection",
  features: [{
    type: "Feature",
    properties: { node_u: "G-001", node_v: "G-002", prob: 0.91, model_class: 1, class: 1, length: 180.5 },
    geometry: { type: "LineString", coordinates: [[-80, 35], [-80, 35.0005]] },
  }],
};
const decorated = context.decorateLiveResult(livePipeResult, "job-123", 0.5);
assert.equal(decorated.features[0].properties.job_id, "job-123");
assert.equal(decorated.features[0].properties.analysis_mode, "live_api");
assert.equal(decorated.features[0].properties.deeppipe_outcome, "predicted");
assert.equal(decorated.crs.properties.name, "EPSG:4326");
assert.equal(decorated.features[0].properties.deeppipe_color, "#005035");
// Final selected class outranks raw model scores and legacy classifier flags.
assert.equal(context.predictionResultType({ properties: { class: 1, model_class: 0, prob: 0.08 } }, 0.85), "predicted");
assert.equal(context.predictionResultType({ properties: { class: 0, model_class: 1, prob: 0.99 } }, 0.5), "excluded");
assert.equal(context.predictionResultType({ properties: { result_type: "candidate" } }, 0.5), "excluded");
assert.equal(context.predictionResultType({ properties: { probability: 0.92 } }, 0.5), "unknown");
assert.equal(context.predictionResultType({ properties: { workflow_type: "legacy", class: 0, model_class: 1, prob: 0.92 } }, 0.85), "potential");
const finalResult = {
  type: "FeatureCollection",
  features: [
    { type: "Feature", properties: { node_u: "A", node_v: "B", class: 1, model_prob: 0.08, prob: 1, observation: 1, model_class: 0 }, geometry: null },
    { type: "Feature", properties: { node_u: "B", node_v: "C", class: 0, model_prob: 0.99, prob: 0.99, observation: 0 }, geometry: null },
    { type: "Feature", properties: { node_u: "A", node_v: "C", class: 1, neural_probability: 0.72, effective_probability: 0.72 }, geometry: null },
    { type: "Feature", properties: { node_u: "C", node_v: "D", class: 0, model_prob: 0.95, prob: 0.95 }, geometry: null },
  ],
};
const finalCopy = JSON.stringify(finalResult);
const finalDecorated = context.decorateLiveResult(finalResult, "refined-job", 0.5);
assert.equal(JSON.stringify(finalResult), finalCopy, "decorate must not mutate server data");
const forced = finalDecorated.features[0].properties;
assert.equal(forced.model_prob, 0.08);
assert.equal(forced.prob, 1);
assert.equal(forced.effective_prob, 1);
assert.equal(forced.effective_probability, 1);
assert.equal(forced.deeppipe_outcome, "predicted");
assert.equal(forced.deeppipe_color, "#005035");
assert.equal(finalDecorated.features[1].properties.model_prob, 0.99);
assert.equal(finalDecorated.features[1].properties.prob, 0);
const unscoredConfirmed = {type:"FeatureCollection", features:[{
  type:"Feature", properties:{node_u:"A",node_v:"D",class:1,model_prob:null,prob:1,observation:1}, geometry:null,
}]};
assert.equal(context.decorateLiveResult(unscoredConfirmed, "new").features[0].properties.model_prob, null);
assert.equal(context.observationRows(unscoredConfirmed, [])[0].model_prob, null, "a hard effective score must not become a fabricated model score");
assert.equal("model_prob" in context.effectivePredictionProperties({class:1,prob:1,observation:1}), false);
const partitioned = context.partitionPredictionResults(finalDecorated, 0.5);
assert.equal(partitioned.predictedCount, 2);
assert.equal(partitioned.potentialCount, 0);
assert.equal(partitioned.excludedCount, 2);
assert.equal(partitioned.total, 2);
assert.equal(context.summarizeLiveResult(finalDecorated, 4, 0.5).predicted, 2);
const resultTable = context.predictionAttributeTable(partitioned.predicted);
assert.equal(resultTable.rows.length, 2);
assert.ok(resultTable.columns.some(column => column.key === "model_prob" && column.label === "Model probability"));
assert.ok(resultTable.columns.some(column => column.key === "class" && column.label === "Final selected class"));

assert.equal(
  context.featureCollectionMultiLineWkt(livePipeResult),
  "MULTILINESTRING ((-80 35, -80 35.0005))",
);
const sameOutcomeOverlayWkt = context.multiLineWktFromFeatureWkts([
  "LineString (-80 35, -80 35.0005)",
  "LineString (-80 35.0005, -79.9995 35.001)",
]);
assert.equal(
  sameOutcomeOverlayWkt,
  "MULTILINESTRING ((-80 35, -80 35.0005), (-80 35.0005, -79.9995 35.001))",
);
assert.doesNotMatch(sameOutcomeOverlayWkt, /GEOMETRYCOLLECTION/i);
assert.equal(
  context.multiLineWktFromFeatureWkts([
    "MultiLineString ((0 0, 1 1), (1 1, 2 1))",
    "LineString (2 1, 3 2)",
  ]),
  "MULTILINESTRING ((0 0, 1 1), (1 1, 2 1), (2 1, 3 2))",
);

assert.equal(context.normalizeJobStatus("SUCCESS"), "succeeded");
assert.equal(context.normalizeJobStatus("REVOKED"), "cancelled");
assert.equal(context.normalizeJobStatus("PENDING"), "queued");
assert.equal(context.normalizeJobStatus("STARTED"), "running");
assert.equal(context.statusMessage({ info: { step: "Extracting factors" } }), "Extracting factors");

assert.equal(context.normalizeHttpsUrl("https://example.org/tiles/{z}/{x}/{y}.png"), "https://example.org/tiles/{z}/{x}/{y}.png");
assert.equal(context.normalizeHttpsUrl("http://example.org/tiles/{z}/{x}/{y}.png"), "");
assert.equal(context.normalizeHttpsUrl("file:///tmp/layer.tif"), "");
assert.match(
  context.xyzRasterUri("https://example.org/tiles/{z}/{x}/{y}.png?gauge=16&min_years=20", 4, 19),
  /url=https:\/\/example\.org\/tiles\/%7Bz%7D\/%7Bx%7D\/%7By%7D\.png%3Fgauge%3D16%26min_years%3D20/,
);
assert.equal(
  context.pypassTileTransportUrl("https://lab.yyworkshop.com/api/pypass/tiles/ph/{z}/{x}/{y}.png"),
  "https://lab.yyworkshop.com/api/pypass/tiles/ph/{z}/{x}/{y}%2Epng",
);
assert.equal(
  context.pypassTileTransportUrl(
    "https://lab.yyworkshop.com/api/pypass/service-life-tiles/galvanized/{z}/{x}/{y}.png?min_years=50&gauge=16",
  ),
  "https://lab.yyworkshop.com/api/pypass/service-life-tiles/galvanized/{z}/{x}/{y}%2Epng?min_years=50&gauge=16",
);
assert.equal(
  context.pypassTileTransportUrl("https://example.org/tiles/{z}/{x}/{y}.png"),
  "https://example.org/tiles/{z}/{x}/{y}.png",
);
assert.match(
  context.xyzRasterUri("https://lab.yyworkshop.com/api/pypass/tiles/ph/{z}/{x}/{y}%2Epng", 7, 19),
  /%7By%7D%252Epng/,
);
assert.equal(context.appendUrlQuery("/tiles/{z}/{x}/{y}.png", "min_years=20"), "/tiles/{z}/{x}/{y}.png?min_years=20");
assert.equal(context.appendUrlQuery("/tiles/{z}/{x}/{y}.png?style=life", "min_years=20"), "/tiles/{z}/{x}/{y}.png?style=life&min_years=20");
assert.equal(context.passVariableTilePath("ph"), "/api/pypass/tiles/ph/{z}/{x}/{y}.png");
assert.equal(
  context.passServiceLifeTilePath("galvanized", 25, 16),
  "/api/pypass/service-life-tiles/galvanized/{z}/{x}/{y}.png?min_years=25&gauge=16",
);
const aluminumGauge = context.passRasterGauge("aluminum", 18, [{
  id: "aluminum",
  requires_gauge: true,
  gauge_sizes: [8, 10, 12, 14, 16],
  default_gauge: 12,
}]);
assert.equal(aluminumGauge.gauge, 12);
assert.equal(aluminumGauge.adjusted, true);
assert.equal(context.passRasterGauge("steel", 18, []).gauge, 18);
assert.equal(context.passRasterGauge("rcp", 18, []).requiresGauge, false);

const liveAssessment = context.normalizeLiveAssessment({
  location: { latitude: 35.2, longitude: -80.8 },
  nominal_diameter_cast_iron: 16,
  soil: { ph: null, resistivity_ohm_cm: 10000, chloride: "High" },
  service_life: {
    fixed_materials: {
      reinforced_concrete_pipe_rcp_years: 33.4,
      cast_iron_pipe_years: null,
      plastic_pipes_hdpe_pp_pvc_years: 75,
    },
    gauge_materials: [{
      gauge: 16,
      galvanized_pipe_years: 80,
      aluminized_csp_type_2_pipe_years: null,
      aluminum_pipe_years: 90,
      steel_pipe_years: 70,
    }],
  },
  warnings: ["pH is unavailable for this location."],
}, 16);
assert.equal(liveAssessment.ok, true);
assert.equal(liveAssessment.soil.ph, null);
assert.equal(liveAssessment.soil.resistivity_ohm_cm, 10000);
assert.equal(liveAssessment.estimates.find((item) => item.id === "cast_iron").years, null);
assert.equal(liveAssessment.estimates.find((item) => item.id === "galvanized").years, 80);
assert.equal(liveAssessment.warnings.length, 1);
assert.equal(context.normalizeLiveAssessment({
  location: { latitude: 35.2, longitude: -80.8 },
  soil: { ph: null, resistivity_ohm_cm: null, chloride: "" },
  service_life: { fixed_materials: {}, gauge_materials: [] },
}, 16).soil.chloride, null);
assert.equal(context.normalizeLiveAssessment({
  location: { latitude: 35.2, longitude: -80.8 },
  soil: {},
}, 16).ok, false);

const assessmentA = context.buildMockAssessment(35.2271, -80.8431, 16);
const assessmentB = context.buildMockAssessment(35.2271, -80.8431, 16);
assert.equal(assessmentA.ok, true);
assert.equal(assessmentA.estimates.length, 7);
assert.equal(JSON.stringify(assessmentA), JSON.stringify(assessmentB));
assert.equal(context.buildMockAssessment(200, -80, 16).ok, false);

console.log("DeepPipe pure-JS tests passed.");
