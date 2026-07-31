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
for (const expected of ["[general]", "name=DeepPipe Mobile", "version=0.3.0", "icon=icon.svg"]) {
  assert.equal(metadata.includes(expected), true, `metadata.txt lacks ${expected}`);
}

const main = fs.readFileSync(path.join(pluginRoot, "main.qml"), "utf8");
for (const expected of [
  "iface.addItemToPluginsToolbar",
  "pointHandler.registerHandler",
  "LayerUtils.createFeatureIteratorFromRectangle",
  "LayerUtils.memoryLayerFromJsonString",
  "ProjectUtils.addMapLayer",
  "iface.createHttpRequest",
  "iface.findItemByObjectName(\"pointHandler\")",
  "CoordinateReferenceSystemUtils.wgs84Crs",
  "GeometryUtils.reprojectRectangle",
  "projectMappingsJson",
  "qgisProject.fileName",
  "addInletsInScreenRectangle",
  "selectVisibleInlets",
  "/api/pred/pred_deep",
  "/api/jobs/jobs/",
]) {
  assert.equal(main.includes(expected), true, `main.qml lacks ${expected}`);
}
assert.equal(main.includes("readProjectBoolEntry"), false, "main.qml still hard-gates projects on DeepPipe/enabled");
assert.equal(main.includes("Project setup required"), false, "main.qml retains the old non-actionable setup error");

const panel = fs.readFileSync(path.join(pluginRoot, "DeepPipePanel.qml"), "utf8");
for (const expected of [
  "PRED LIVE",
  "Use this project setup",
  "uuid('WithoutBraces')",
  "Test API connection",
  "Cancel active prediction",
  "Assessment remains mock",
]) {
  assert.equal(panel.includes(expected), true, `DeepPipePanel.qml lacks ${expected}`);
}

const logic = fs.readFileSync(path.join(pluginRoot, "logic/DeepPipe.js"), "utf8");
for (const expected of ["featureCollectionFromPoints", "validateLiveSelectedPoints", "choosePipeResultFilename", "decorateLiveResult"]) {
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
for (const expected of ["<qgis", "</qgis>", "api_base_url", "inlets.geojson"]) {
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

console.log("DeepPipe QField source and demo-project structure checks passed.");
