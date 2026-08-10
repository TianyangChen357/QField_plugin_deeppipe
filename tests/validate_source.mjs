import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const pluginRoot = path.resolve(here, "../plugin/deeppipe-mobile");
const projectRoot = path.resolve(here, "../project-template");

for (const required of ["main.qml", "metadata.txt", "icon.svg", "results-table.svg", "DeepPipePanel.qml", "logic/DeepPipe.js"]) {
  assert.equal(fs.existsSync(path.join(pluginRoot, required)), true, `Missing ${required}`);
}

const metadata = fs.readFileSync(path.join(pluginRoot, "metadata.txt"), "utf8");
for (const expected of ["[general]", "name=DeepPipe Mobile", "version=0.6.1", "icon=icon.svg", "description=DeepPipe Stormwater Pipe Prediction and Service Life Assessment for QField"]) {
  assert.equal(metadata.includes(expected), true, `metadata.txt lacks ${expected}`);
}

const main = fs.readFileSync(path.join(pluginRoot, "main.qml"), "utf8");
assert.equal(main.includes('readonly property string pluginVersion: "0.6.1"'), true, "main.qml has the wrong plugin version");
for (const expected of [
  "iface.addItemToPluginsToolbar",
  "handler.registerHandler",
  "LayerUtils.createFeatureIteratorFromRectangle",
  "LayerUtils.memoryLayerFromJsonString",
  "LayerUtils.loadVectorLayer",
  "LayerUtils.saveVectorLayerAs",
  "LayerUtils.loadRasterLayer",
  "ProjectUtils.addMapLayer",
  "iface.createHttpRequest",
  "iface.findItemByObjectName(\"pointHandler\")",
  "CoordinateReferenceSystemUtils.wgs84Crs",
  "GeometryUtils.reprojectRectangle",
  "projectMappingsJson",
  "projectServiceSettingsJson",
  "projectPredictionResultsJson",
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
  "createPredictionResultLayer",
  "attachPersistentPredictionLayer",
  "restorePersistedPredictionResult",
  "clearPredictionResults",
  "QFieldItems.GeometryRenderer",
  "DeepPipe.multiLineWktFromFeatureWkts",
  "DeepPipe.pypassTileTransportUrl",
  "predictionAttributeTable",
  "predictionLayerLegendVisible",
  "iface.addItemToCanvasActionsToolbar",
  "focusPredictionResult",
  "GeometryUtils.boundingBox",
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
const completedBlock = main.match(/Component\.onCompleted\s*:\s*\{([\s\S]*?)\n\s*\}/)?.[1] || "";
assert.equal(completedBlock.includes("ensurePointHandlerRegistered"), false, "main.qml registers the point handler while idle at startup");
assert.equal(main.includes("property var predictionResultLayers"), false, "main.qml still maintains duplicate prediction layers");
assert.equal(main.includes("function suggestedLayerId"), false, "main.qml still auto-selects an inlet layer for a fresh project");
assert.equal(main.includes("DeepPipe.suggestedNodeIdField"), false, "main.qml still auto-selects or carries an ID field");
assert.equal(main.includes('nodeIdField = "";'), true, "changing the inlet layer does not clear the prior ID field");
assert.equal(
  main.includes('"GEOMETRYCOLLECTION (" + wkts.join'),
  false,
  "main.qml aggregates result overlays into an unsupported GeometryCollection",
);
assert.equal(main.includes("layer.opacity = 1.0"), true, "the persistent result layer lacks a native-renderer fallback");
for (const removed of ["remoteCog", "remote_cog", "gdalRemoteRasterUri", "apiBaseUrlRequested", "passApiBaseUrlRequested"]) {
  assert.equal(main.includes(removed), false, `main.qml retains removed configuration ${removed}`);
}

const panel = fs.readFileSync(path.join(pluginRoot, "DeepPipePanel.qml"), "utf8");
assert.equal(panel.includes('property string pluginVersion: "0.6.1"'), true, "DeepPipePanel.qml has the wrong plugin version");
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
  "2  Run pipeline prediction",
  "Specify prediction settings (optional)",
  "Reset to DeepPipe defaults",
  "GNN probability",
  "Pipe material",
  "Not applicable for this material",
  "DeepPipe field guide",
  "Cancel active prediction",
  "Save another GeoJSON copy",
  "View result attribute table",
  "predictionRowRequested",
  "tap a row to zoom and highlight",
  "Download complete job ZIP",
  "Point-based query",
  "Raster-based query",
  "Gauge-dependent point estimates use gauge",
  "View Service Life Raster on Map",
  "Clear prediction results",
]) {
  assert.equal(panel.includes(expected), true, `DeepPipePanel.qml lacks ${expected}`);
}
assert.ok(
  panel.indexOf("2  Run pipeline prediction") < panel.indexOf("Specify prediction settings (optional)"),
  "the primary Prediction action must appear before optional settings",
);
assert.equal(panel.includes("property bool predictionSettingsExpanded: false"), true, "optional prediction settings are not closed by default");
assert.ok(
  panel.indexOf("onClicked: panel.runPredictionRequested()") < panel.indexOf("id: predictionSettingsDisclosure"),
  "the Predict button appears after the optional-settings disclosure",
);
assert.equal(panel.includes("visible: panel.predictionSettingsExpanded"), true, "advanced prediction controls are not disclosure-controlled");
assert.equal(panel.includes("Select an inlet layer first"), true, "the ID field lacks its disabled pre-layer state");
assert.equal(panel.includes("panel.inletLayerId.length > 0 ? panel.fieldNames : []"), true, "the ID field model is not scoped to the selected layer");
for (const removed of ["predictionLayerBox", "Choose the field inlet layer", "elevationWeightSlider", 'text: "Elevation"']) {
  assert.equal(panel.includes(removed), false, `DeepPipePanel.qml retains removed prediction UI ${removed}`);
}
for (const removed of [
  "1  Assessment location",
  "2  Compare service-life estimates",
  "3  Review hosted raster layers",
  "addPassVariableRasterRequested",
  "Run live service-life assessment",
]) {
  assert.equal(panel.includes(removed), false, `DeepPipePanel.qml retains removed assessment UI ${removed}`);
}
assert.equal(
  main.includes('setAssessmentLocation(Number(wgs84.y), Number(wgs84.x), "Map point");') &&
    main.includes("panelDrawer.open();\n        runLiveAssessment();"),
  true,
  "map-point selection does not auto-run the live assessment",
);
assert.equal(
  main.includes('setAssessmentLocation(information.latitude, information.longitude, "GNSS");\n        runLiveAssessment();'),
  true,
  "GNSS selection does not auto-run the live assessment",
);
assert.equal(main.includes("DeepPipe.xyzRasterUri(transportUrl, 5, 19)"), true, "XYZ raster minimum zoom is not regional-view friendly");
assert.equal(main.includes('addManagedRasterLayer(uri, layerName, "wms", 1.0, Boolean(replaceAll))'), true, "XYZ raster opacity still dims server-rendered tiles");
assert.equal(main.includes('addXyzRasterFromTemplate(template, layerName, true)'), true, "service-life raster does not replace the previous managed raster");
assert.equal(main.includes('onRemovePredictionLayerRequested: plugin.clearPredictionResults()'), true, "Clear prediction results is not connected to the full clear action");
const clearResultsBlock = main.match(/function clearPredictionResults[\s\S]*?\n\s*function predictionResultFilePath/)?.[0] || "";
assert.equal(clearResultsBlock.includes("removePredictionLayer(false, false)"), true, "Clear prediction results preserves a stored result or completed job");
const rasterInputsBlock = main.match(/function setRasterInputs[\s\S]*?\n\s*function addManagedRasterLayer/)?.[0] || "";
assert.equal(rasterInputsBlock.includes("assessmentResult = null"), false, "raster inputs still clear the point-query result");

const logic = fs.readFileSync(path.join(pluginRoot, "logic/DeepPipe.js"), "utf8");
for (const expected of [
  "featureCollectionFromPoints",
  "validateLiveSelectedPoints",
  "choosePipeResultFilename",
  "decorateLiveResult",
  "partitionPredictionResults",
  "predictionResultState",
  "updatePredictionResultState",
  "predictionAttributeTable",
  "featureCollectionMultiLineWkt",
  "multiLineWktFromFeatureWkts",
  "normalizeLiveAssessment",
  "normalizeHttpsUrl",
  "pypassTileTransportUrl",
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
