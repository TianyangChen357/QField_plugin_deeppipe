import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const pluginRoot = path.resolve(here, "../plugin/deeppipe-mobile");
const projectRoot = path.resolve(here, "../project-template");

for (const required of ["main.qml", "metadata.txt", "icon.svg", "DeepPipePanel.qml", "logic/DeepPipe.js"]) {
  assert.equal(fs.existsSync(path.join(pluginRoot, required)), true, `Missing ${required}`);
}

const metadata = fs.readFileSync(path.join(pluginRoot, "metadata.txt"), "utf8");
for (const expected of ["[general]", "name=DeepPipe Mobile", "version=0.5.13", "icon=icon.svg"]) {
  assert.equal(metadata.includes(expected), true, `metadata.txt lacks ${expected}`);
}

const main = fs.readFileSync(path.join(pluginRoot, "main.qml"), "utf8");
assert.equal(main.includes('readonly property string pluginVersion: "0.5.13"'), true, "main.qml has the wrong plugin version");
for (const expected of [
  "iface.addItemToPluginsToolbar",
  "handler.registerHandler",
  "LayerUtils.createFeatureIteratorFromRectangle",
  "LayerUtils.memoryLayerFromJsonString",
  "LayerUtils.saveVectorLayerAs",
  "LayerUtils.loadRasterLayer",
  "ProjectUtils.addMapLayer",
  "iface.createHttpRequest",
  "iface.findItemByObjectName(\"pointHandler\")",
  "CoordinateReferenceSystemUtils.wgs84Crs",
  "GeometryUtils.reprojectRectangle",
  "projectMappingsJson",
  "projectServiceSettingsJson",
  "DeepPipe.projectServiceSettings",
  "DeepPipe.updateProjectServiceSettings",
  "qgisProject.fileName",
  "addInletsInScreenRectangle",
  "selectVisibleInlets",
  "/api/pred/pred_deep",
  "/api/jobs/jobs/",
  "/api/pypass/service-life",
  "/api/pypass/variables",
  "ensurePointHandlerRegistered",
  "mapRectangleFromScreenBounds",
  "GeometryUtils.point(minimumX, minimumY)",
  "mapInteractionOverlay",
  "testApiConnections",
  "setPredictionConfig",
  "createPredictionResultLayers",
  "QFieldItems.GeometryRenderer",
  "featureCollectionMultiLineWkt",
  "predictionAttributeTable",
  "/download",
  "Qt.openUrlExternally",
  "platformUtilities.sendDatasetTo",
]) {
  assert.equal(main.includes(expected), true, `main.qml lacks ${expected}`);
}
assert.equal(main.includes("readProjectBoolEntry"), false, "main.qml still hard-gates projects on DeepPipe/enabled");
assert.equal(main.includes("Project setup required"), false, "main.qml retains the old non-actionable setup error");
assert.equal(
  main.includes("Boolean(handler.registerHandler"),
  false,
  "main.qml treats QField's void registerHandler() result as a Boolean",
);
assert.equal(
  main.includes("/DeepPipe_exports/"),
  false,
  "main.qml exports into a child directory that the plugin does not create",
);
assert.equal(main.includes("MapCanvasPointHandler.Priority"), false, "main.qml references a QField-local QML type unavailable to app plugins");
assert.equal(main.includes("Qt.point(minimumX, minimumY)"), false, "main.qml passes QPointF values to createRectangleFromPoints");
for (const removed of ["remoteCog", "remote_cog", "gdalRemoteRasterUri", "apiBaseUrlRequested", "passApiBaseUrlRequested"]) {
  assert.equal(main.includes(removed), false, `main.qml retains removed configuration ${removed}`);
}

const panel = fs.readFileSync(path.join(pluginRoot, "DeepPipePanel.qml"), "utf8");
assert.equal(panel.includes('property string pluginVersion: "0.5.13"'), true, "DeepPipePanel.qml has the wrong plugin version");
for (const duplicateFontAssignment of ["font: setupTab.font", "font: predictionTab.font", "font: assessmentTab.font"]) {
  assert.equal(panel.includes(duplicateFontAssignment), false, `DeepPipePanel.qml retains ${duplicateFontAssignment}`);
}
for (const expected of [
  "PRED LIVE",
  "Use this project setup",
  "uuid('WithoutBraces')",
  "Configuration",
  "Pipeline Prediction",
  "Service Life Assessment",
  "Check API status",
  "Number of neighbors (k)",
  "Enable MST post-processing",
  "1  Select inlets on the map",
  "2  Prediction settings",
  "GNN probability",
  "Pipe material",
  "Not applicable for this material",
  "DeepPipe field guide",
  "Cancel active prediction",
  "Save combined result as GeoJSON",
  "View result attribute table",
  "Download complete job ZIP",
  "Run live service-life assessment",
]) {
  assert.equal(panel.includes(expected), true, `DeepPipePanel.qml lacks ${expected}`);
}
for (const removed of ["predictionLayerBox", "Choose the field inlet layer", "elevationWeightSlider", 'text: "Elevation"']) {
  assert.equal(panel.includes(removed), false, `DeepPipePanel.qml retains removed prediction UI ${removed}`);
}

const logic = fs.readFileSync(path.join(pluginRoot, "logic/DeepPipe.js"), "utf8");
for (const expected of [
  "featureCollectionFromPoints",
  "validateLiveSelectedPoints",
  "choosePipeResultFilename",
  "decorateLiveResult",
  "partitionPredictionResults",
  "predictionAttributeTable",
  "featureCollectionMultiLineWkt",
  "normalizeLiveAssessment",
  "normalizeHttpsUrl",
  "xyzRasterUri",
  "resolveCatalogUrl",
  "passRasterGauge",
]) {
  assert.equal(logic.includes(expected), true, `DeepPipe.js lacks ${expected}`);
}

function balancedDelimiters(text, filename) {
  const stack = [];
  const pairs = { ")": "(", "]": "[", "}": "{" };
  let quote = null;
  let escaped = false;
  let lineComment = false;
  let blockComment = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];
    if (lineComment) {
      if (char === "\n") lineComment = false;
      continue;
    }
    if (blockComment) {
      if (char === "*" && next === "/") {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote) {
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === quote) quote = null;
      continue;
    }
    if (char === "/" && next === "/") {
      lineComment = true;
      index += 1;
      continue;
    }
    if (char === "/" && next === "*") {
      blockComment = true;
      index += 1;
      continue;
    }
    if (char === '"' || char === "'") {
      quote = char;
      continue;
    }
    if ("([{ ".includes(char) && char !== " ") stack.push(char);
    if (pairs[char]) assert.equal(stack.pop(), pairs[char], `${filename}: unbalanced ${char}`);
  }
  assert.equal(quote, null, `${filename}: unterminated string`);
  assert.equal(blockComment, false, `${filename}: unterminated block comment`);
  assert.equal(stack.length, 0, `${filename}: unclosed delimiter`);
}

for (const qml of ["main.qml", "DeepPipePanel.qml"]) {
  balancedDelimiters(fs.readFileSync(path.join(pluginRoot, qml), "utf8"), qml);
}

const demoProject = fs.readFileSync(path.join(projectRoot, "DeepPipe_Mobile_Demo.qgs"), "utf8");
for (const expected of ["<qgis", "</qgis>", "api_mode", "inlets.geojson"]) {
  assert.equal(demoProject.includes(expected), true, `Demo QGIS project lacks ${expected}`);
}

const demoInlets = JSON.parse(fs.readFileSync(path.join(projectRoot, "data/inlets.geojson"), "utf8"));
assert.equal(demoInlets.type, "FeatureCollection");
assert.ok(Array.isArray(demoInlets.features) && demoInlets.features.length >= 3);
for (const feature of demoInlets.features) {
  assert.equal(feature.geometry?.type, "Point");
  assert.ok(String(feature.properties?.node_id || "").trim());
  assert.match(String(feature.properties?.inlet_uuid || ""), /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
}
assert.equal(new Set(demoInlets.features.map((feature) => feature.properties.inlet_uuid)).size, demoInlets.features.length);
assert.ok(demoProject.includes("<node_id_field type=\"QString\">inlet_uuid</node_id_field>"));
assert.ok(demoProject.includes("uuid('WithoutBraces')"));
assert.equal(demoProject.includes("api_base_url"), false);
assert.equal(demoProject.includes("pypass_api_base_url"), false);
assert.equal(demoProject.includes("remote_cog"), false);

console.log("DeepPipe QField source and demo-project structure checks passed.");
