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

const points = [
  { fid: 1, nodeId: "I-001", x: 0, y: 0 },
  { fid: 2, nodeId: "I-002", x: 10, y: 0 },
  { fid: 3, nodeId: "I-003", x: 10, y: 10 },
  { fid: 4, nodeId: "I-004", x: 30, y: 10 },
];

const defaults = context.predictionDefaults();
assert.equal(defaults.model_type, "gnn");
assert.equal(defaults.k_neighbors, 12);
assert.equal(defaults.classification_threshold, 0.85);

const normalized = context.normalizePredictionConfig({
  max_search_radius: 5000,
  classification_threshold: 0.2,
  prob_weight: 2,
  elev_weight: 1,
  length_weight: 1,
});
assert.equal(normalized.max_search_radius, 1500);
assert.equal(normalized.classification_threshold, 0.51);
assert.ok(Math.abs(normalized.prob_weight + normalized.elev_weight + normalized.length_weight - 1) < 1e-9);

assert.equal(
  context.suggestedNodeIdField(["name", "node_id", "inlet_uuid"], ""),
  "inlet_uuid",
);
assert.equal(
  context.suggestedNodeIdField(["name", "node_id", "inlet_uuid"], "node_id"),
  "node_id",
);
assert.equal(context.projectKey("/projects/a.qgs", "Same title"), "path:/projects/a.qgs");
assert.equal(context.projectKey("", "Same title"), "title:Same title");
const mappingJson = context.updateProjectMapping("{}", "/projects/a.qgs", "Same title", {
  layer_id: "layer-a",
  layer_name: "Inlets",
  node_id_field: "inlet_uuid",
  confirmed_at: "2026-07-31T18:00:00.000Z",
});
assert.equal(
  context.projectMapping(mappingJson, "/projects/a.qgs", "Same title").node_id_field,
  "inlet_uuid",
);
assert.equal(
  context.projectMapping(mappingJson, "/projects/moved.qgs", "Same title"),
  null,
);
assert.equal(context.projectMapping(mappingJson, "/projects/b.qgs", "Same title"), null);
assert.equal(context.projectMapping("not json", "/projects/a.qgs", "Same title"), null);

let serviceSettingsJson = context.updateProjectServiceSettings(
  "{}",
  "/projects/a.qgs",
  "Same title",
  {
    prediction_config: {
      model_type: "gnn",
      k_neighbors: 8,
      with_mst: false,
      prob_weight: 0.2,
      elev_weight: 0.3,
      length_weight: 0.5,
    },
  },
);
serviceSettingsJson = context.updateProjectServiceSettings(
  serviceSettingsJson,
  "/projects/b.qgs",
  "Same title",
  {
    prediction_config: {
      model_type: "mlp",
      k_neighbors: 18,
      with_mst: true,
      prob_weight: 0.5,
      elev_weight: 0.0,
      length_weight: 0.5,
    },
  },
);
assert.equal(
  context.projectServiceSettings(serviceSettingsJson, "/projects/a.qgs", "Same title").prediction_config.k_neighbors,
  8,
);
assert.equal(
  context.projectServiceSettings(serviceSettingsJson, "/projects/b.qgs", "Same title").prediction_config.k_neighbors,
  18,
);
assert.equal(
  context.projectServiceSettings(serviceSettingsJson, "/projects/b.qgs", "Same title").prediction_config.model_type,
  "mlp",
);
assert.equal(context.projectServiceSettings(serviceSettingsJson, "/projects/c.qgs", "Same title"), null);

let resultStatesJson = context.updatePredictionResultState(
  "{}",
  "/projects/a.qgs",
  "Same title",
  {
    path: "/projects/DeepPipe_prediction_latest_a.geojson",
    layer_name: "DeepPipe Prediction Results",
    job_id: "job-a",
    threshold: 0.85,
    selected_count: 12,
    saved_at: "2026-08-06T18:00:00.000Z",
  },
);
assert.equal(
  context.predictionResultState(resultStatesJson, "/projects/a.qgs", "Same title").job_id,
  "job-a",
);
assert.equal(
  context.predictionResultState(resultStatesJson, "/projects/a.qgs", "Same title").selected_count,
  12,
);
assert.equal(context.predictionResultState(resultStatesJson, "/projects/b.qgs", "Same title"), null);
resultStatesJson = context.updatePredictionResultState(
  resultStatesJson,
  "/projects/a.qgs",
  "Same title",
  null,
);
assert.equal(context.predictionResultState(resultStatesJson, "/projects/a.qgs", "Same title"), null);

const bulkRecords = Array.from({ length: 500 }, (_, index) => ({
  fid: index + 1,
  nodeId: `uuid-${index + 1}`,
  x: index,
  y: index,
}));
const firstBulkMerge = context.mergePointRecords(bulkRecords.slice(0, 20), bulkRecords);
assert.equal(firstBulkMerge.records.length, 500);
assert.equal(firstBulkMerge.added, 480);
const secondBulkMerge = context.mergePointRecords(firstBulkMerge.records, bulkRecords);
assert.equal(secondBulkMerge.records.length, 500);
assert.equal(secondBulkMerge.added, 0);

assert.equal(context.validateSelectedPoints(points).ok, true);
assert.equal(context.validateSelectedPoints(points.slice(0, 2)).errors[0].code, "TOO_FEW_INLETS");
const duplicateId = points.map((point) => ({ ...point }));
duplicateId[3].nodeId = "I-001";
assert.equal(context.validateSelectedPoints(duplicateId).errors.some((error) => error.code === "DUPLICATE_NODE_ID"), true);

const mst = context.buildMinimumSpanningEdges(points);
assert.equal(mst.length, points.length - 1);
assert.equal(
  JSON.stringify(mst.map((edge) => [edge.from.nodeId, edge.to.nodeId])),
  JSON.stringify([["I-001", "I-002"], ["I-002", "I-003"], ["I-003", "I-004"]]),
);

const firstPrediction = context.buildMockPrediction(points, defaults, "mock-test");
const secondPrediction = context.buildMockPrediction(points, defaults, "mock-test");
assert.equal(firstPrediction.ok, true);
assert.equal(firstPrediction.summary.total, 3);
assert.equal(JSON.stringify(firstPrediction), JSON.stringify(secondPrediction));
assert.equal(firstPrediction.featureCollection.features.every((feature) => feature.geometry.type === "LineString"), true);
assert.equal(firstPrediction.featureCollection.features.every((feature) => feature.properties.analysis_mode === "mock_preview"), true);

const geographicPoints = [
  { fid: 11, nodeId: "G-001", x: -80, y: 35, longitude: -80, latitude: 35 },
  { fid: 12, nodeId: "G-002", x: -80, y: 35.0005, longitude: -80, latitude: 35.0005 },
  { fid: 13, nodeId: "G-003", x: -80, y: 35.001, longitude: -80, latitude: 35.001 },
];
assert.equal(context.validateLiveSelectedPoints(geographicPoints).ok, true);
assert.equal(
  context.validateLiveSelectedPoints([{ ...geographicPoints[0], longitude: 999 }, geographicPoints[1], geographicPoints[2]]).errors[0].code,
  "INVALID_WGS84_GEOMETRY",
);
const liveFeatureCollection = context.featureCollectionFromPoints(geographicPoints, "node_id");
assert.equal(liveFeatureCollection.crs.properties.name, "EPSG:4326");
assert.deepEqual(Array.from(liveFeatureCollection.features[0].geometry.coordinates), [-80, 35]);
assert.equal(liveFeatureCollection.features[0].properties.node_id, "G-001");
const tightRadiusPrediction = context.buildMockPrediction(
  geographicPoints,
  { ...defaults, max_search_radius: 100, classification_threshold: 0.51 },
  "tight-radius",
);
const wideRadiusPrediction = context.buildMockPrediction(
  geographicPoints,
  { ...defaults, max_search_radius: 500, classification_threshold: 0.51 },
  "wide-radius",
);
assert.equal(tightRadiusPrediction.featureCollection.features.every((feature) => feature.properties.within_search_radius === 0), true);
assert.equal(wideRadiusPrediction.featureCollection.features.every((feature) => feature.properties.within_search_radius === 1), true);
assert.equal(tightRadiusPrediction.summary.predicted, 0);
assert.equal(wideRadiusPrediction.summary.predicted, 2);
assert.equal(wideRadiusPrediction.featureCollection.features.every((feature) => feature.properties.distance_ft > 150), true);
const tightRadiusPartitions = context.partitionPredictionResults(
  tightRadiusPrediction.featureCollection,
  tightRadiusPrediction.summary.threshold,
);
assert.equal(tightRadiusPartitions.predictedCount, tightRadiusPrediction.summary.predicted);
assert.equal(tightRadiusPartitions.potentialCount, tightRadiusPrediction.summary.potential);

const request = context.buildPredictionRequest(
  liveFeatureCollection,
  "node_id",
  defaults,
  { client_request_id: "abc", project_id: "demo", layer_id: "inlets", selected_feature_ids: [1, 2, 3] },
);
assert.equal(request.nodes.type, "FeatureCollection");
assert.equal(request.node_id_field, "node_id");
assert.equal(request.k_neighbors, 12);
assert.equal(request.classification_threshold, 0.85);
assert.equal(request.with_mst, true);
assert.equal(request.prob_weight + request.elev_weight + request.length_weight, 1);
assert.equal("schema_version" in request, false);
assert.equal("parameters" in request, false);

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
const decorated = context.decorateLiveResult(livePipeResult, "job-123");
assert.equal(decorated.features[0].properties.job_id, "job-123");
assert.equal(decorated.features[0].properties.analysis_mode, "live_api");
assert.equal(decorated.features[0].properties.deeppipe_outcome, "predicted");
assert.equal(decorated.crs.properties.name, "EPSG:4326");
const thresholdDecorated = context.decorateLiveResult(livePipeResult, "job-123", 0.85);
assert.equal(thresholdDecorated.features[0].properties.deeppipe_outcome, "predicted");
assert.equal(thresholdDecorated.features[0].properties.deeppipe_color, "#005035");
assert.equal(context.predictionResultType({ properties: { class: 0, model_class: 1, prob: 0.92 } }, 0.85), "potential");
assert.equal(context.predictionResultType({ properties: { is_connect: -1 } }, 0.85), "excluded");
assert.equal(context.predictionResultType({ properties: { probability: 0.92 } }, 0.85), "unknown");
assert.equal(context.predictionResultType({ properties: { class: 0, model_class: 1, score: 0.81 } }, 0.85), "excluded");
assert.equal(context.predictionResultType({ properties: { model_class: 0, class: 1, prob: 0.92 } }, 0.85), "excluded");
assert.equal(context.predictionResultType({ properties: { result_type: "candidate" } }, 0.85), "excluded");
const partitioned = context.partitionPredictionResults({
  type: "FeatureCollection",
  features: [
    { type: "Feature", properties: { class: 1, model_class: 1, prob: 0.92 }, geometry: null },
    { type: "Feature", properties: { class: 0, model_class: 1, prob: 0.91 }, geometry: null },
    { type: "Feature", properties: { class: 0, model_class: 1, prob: 0.50 }, geometry: null },
    { type: "Feature", properties: {}, geometry: null },
  ],
}, 0.85);
assert.equal(partitioned.predictedCount, 1);
assert.equal(partitioned.potentialCount, 1);
assert.equal(partitioned.unknownCount, 0);
assert.equal(partitioned.excludedCount, 2);
assert.equal(partitioned.total, 2);
const liveSummary = context.summarizeLiveResult(thresholdDecorated, 3, 0.85);
assert.equal(liveSummary.predicted, 1);
assert.equal(liveSummary.potential, 0);
assert.equal(liveSummary.unknown, 0);

const resultTable = context.predictionAttributeTable({
  type: "FeatureCollection",
  features: partitioned.predicted.features.concat(partitioned.potential.features),
});
assert.equal(resultTable.rows.length, 2);
assert.deepEqual(Array.from(resultTable.columns.slice(0, 6), (column) => column.key), [
  "__row", "deeppipe_outcome", "prob", "class", "model_class", "deeppipe_color",
]);
assert.equal(resultTable.rows[1].deeppipe_outcome, "potential");
assert.equal(resultTable.rows[1].deeppipe_color, "#F4C430");

assert.equal(
  context.featureCollectionMultiLineWkt(livePipeResult),
  "MULTILINESTRING ((-80 35, -80 35.0005))",
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
