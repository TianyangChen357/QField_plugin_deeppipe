// Opt-in integration test: creates three synthetic prediction jobs, then deletes
// only those jobs. Uses the exact request/result helpers shipped to QField.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

if (process.env.DEEPPIPE_RUN_LIVE_PREDICTION !== "1") {
  console.log("Skipped live prediction. Set DEEPPIPE_RUN_LIVE_PREDICTION=1 to create and clean up test jobs.");
  process.exit(0);
}
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const logic = vm.createContext({ console });
vm.runInContext(fs.readFileSync(path.join(root, "plugin/deeppipe-mobile/logic/DeepPipe.js"), "utf8"), logic);
const base = String(process.env.DEEPPIPE_API_BASE_URL || "https://eegs4y29nw3lws.charlotte.edu:8080/deeppipe/predapi").replace(/\/+$/, "");
const fixture = process.env.DEEPPIPE_LIVE_FIXTURE || path.join(root, "project-template/data/inlets.geojson");
const idField = process.env.DEEPPIPE_LIVE_ID_FIELD || "inlet_uuid";
const nodes = JSON.parse(fs.readFileSync(fixture, "utf8"));
// Both supplied fixtures contain longitude/latitude. The live API requires
// explicit CRS metadata, just as QField's point export helper supplies it.
nodes.crs = nodes.crs || { type: "name", properties: { name: "EPSG:4326" } };
const jobs = [];
const plain = value => JSON.parse(JSON.stringify(value));
const key = feature => logic.canonicalNodePair(feature.properties.node_u, feature.properties.node_v).key;
const index = collection => new Map(collection.features.map(feature => [key(feature), feature]));
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

async function request(route, body) {
  const response = await fetch(base + route, {
    method: body === undefined ? "GET" : "POST",
    headers: body === undefined ? {} : { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(30_000),
  });
  const text = await response.text();
  assert.ok(response.ok, `${route}: HTTP ${response.status}: ${text.slice(0, 400)}`);
  return JSON.parse(text);
}

async function submit(route, payload) {
  const job = await request(route, payload);
  assert.ok(job.task_id);
  jobs.push(job.task_id);
  console.log(`Test job ${job.task_id}: ${route.includes("refine") ? "refinement" : "initial prediction"}`);
  return job.task_id;
}

async function wait(id) {
  const deadline = Date.now() + 15 * 60_000;
  while (Date.now() < deadline) {
    const status = await request(`/api/jobs/jobs/${id}/status`);
    const state = logic.normalizeJobStatus(status.status);
    if (state === "succeeded") return;
    assert.ok(!["failed", "cancelled"].includes(state), JSON.stringify(status));
    await pause(2000);
  }
  throw new Error(`Timed out waiting for ${id}`);
}

async function outputs(id) {
  const pipes = await request(`/api/jobs/jobs/${id}/geojson/Pipes.geojson`);
  const candidates = await request(`/api/jobs/jobs/${id}/geojson/Candidates.geojson`);
  const decorated = logic.decorateLiveResult(pipes, id, 0.5);
  const partitioned = logic.partitionPredictionResults(decorated, 0.5);
  assert.equal(partitioned.predictedCount, pipes.features.length, "QField must retain every final pipe regardless of raw probability");
  assert.equal(partitioned.potentialCount, 0);
  assert.ok(pipes.features.every(feature => Number(feature.properties.class) === 1));
  return { pipes, candidates };
}

try {
  const payload = logic.buildPredictionRequest(nodes, idField, logic.predictionDefaults());
  assert.equal(payload.workflow_type, "progressive");
  assert.equal(payload.model_type, "progressive_gnn");
  const parent = await submit("/api/pred/pred_deep", payload);
  await wait(parent);
  const initial = await outputs(parent);
  assert.ok(initial.pipes.features.length > 0, "Fixture must produce a selected edge to reject");
  const original = index(initial.candidates);
  const ids = nodes.features.map(feature => String(feature.properties[idField]));
  let missing;
  for (let i = 0; i < ids.length && !missing; i++) {
    for (let j = i + 1; j < ids.length; j++) {
      const pair = logic.canonicalNodePair(ids[i], ids[j]);
      if (!original.has(pair.key)) { missing = pair; break; }
    }
  }
  assert.ok(missing, "Fixture must contain a pair outside the generated candidates");
  const rejected = initial.pipes.features[0].properties;
  let observations = logic.setObservation([], missing.node_u, missing.node_v, "connected", nodes, idField);
  observations = logic.setObservation(observations, rejected.node_u, rejected.node_v, "disconnected", nodes, idField);
  const child = await submit(`/api/pred/jobs/${parent}/refine`, logic.buildRefinementRequest(observations, nodes, idField));
  await wait(child);
  const refined = await outputs(child);
  const selected = index(refined.pipes);
  const scored = index(refined.candidates);
  assert.ok(selected.has(missing.key), "A confirmed pair outside the initial candidates must become a final pipe");
  assert.equal(Number(selected.get(missing.key).properties.prob), 1);
  const rejectedKey = logic.canonicalNodePair(rejected.node_u, rejected.node_v).key;
  assert.ok(!selected.has(rejectedKey), "A rejected pipe must be excluded");
  assert.equal(Number(scored.get(rejectedKey).properties.prob), 0);
  const changed = [...original].filter(([edge, feature]) => {
    if (edge === rejectedKey || !scored.has(edge)) return false;
    const before = Number(feature.properties.model_prob);
    const after = Number(scored.get(edge).properties.model_prob);
    return Number.isFinite(before) && Number.isFinite(after) && Math.abs(before - after) > 1e-7;
  }).length;
  assert.ok(changed > 0, "Observation feedback must rerun neural inference and affect unknown scores");
  const clear = await submit(`/api/pred/jobs/${child}/refine`, logic.buildRefinementRequest([], nodes, idField));
  await wait(clear);
  const restored = await outputs(clear);
  const cleared = index(restored.candidates);
  assert.deepEqual([...cleared.keys()].sort(), [...original.keys()].sort(), "Clearing observations must restore the original candidate input");
  for (const [edge, feature] of original) {
    assert.ok(Math.abs(Number(feature.properties.model_prob) - Number(cleared.get(edge).properties.model_prob)) < 1e-5,
      `Clearing observations must restore the unconditioned score for ${edge}`);
  }
  assert.deepEqual([...index(restored.pipes).keys()].sort(), [...index(initial.pipes).keys()].sort());
  console.log(`Live Progressive passed: ${nodes.features.length} nodes; ${original.size} initial candidates; added outside pair; rejected existing pipe; ${changed} unknown scores changed; empty snapshot restored baseline.`);
} finally {
  for (const id of jobs.reverse()) {
    try {
      let status = await request(`/api/jobs/jobs/${id}/status`);
      if (!["succeeded", "failed", "cancelled"].includes(logic.normalizeJobStatus(status.status))) {
        await request(`/api/jobs/jobs/${id}/cancel`, {});
        for (let attempt = 0; attempt < 30; attempt++) {
          await pause(1000);
          status = await request(`/api/jobs/jobs/${id}/status`);
          if (["succeeded", "failed", "cancelled"].includes(logic.normalizeJobStatus(status.status))) break;
        }
      }
      await request(`/api/jobs/jobs/${id}/delete`, {});
      console.log(`Deleted test job ${id}`);
    } catch (error) {
      console.error(`Cleanup needed for test job ${id}: ${error.message}`);
      process.exitCode = 1;
    }
  }
}
