import assert from "node:assert/strict";

const baseUrl = String(process.env.DEEPPIPE_API_BASE_URL || "https://lab.yyworkshop.com/predapi").replace(/\/+$/, "");

async function request(path, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20_000);
  try {
    return await fetch(baseUrl + path, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

const healthResponse = await request("/health");
assert.equal(healthResponse.status, 200);
const health = await healthResponse.json();
assert.equal(health.status, "ok");

const openApiResponse = await request("/openapi.json");
assert.equal(openApiResponse.status, 200);
const openApi = await openApiResponse.json();
assert.equal(openApi.info.title, "DeepPipe Prediction API");
assert.ok(openApi.paths["/api/pred/pred_deep"]?.post);
assert.ok(openApi.paths["/api/jobs/jobs/{task_id}/status"]?.get);
assert.ok(openApi.paths["/api/jobs/jobs/{task_id}/files"]?.get);
assert.ok(openApi.paths["/api/jobs/jobs/{task_id}/geojson/{filename}"]?.get);

const submitOperation = openApi.paths["/api/pred/pred_deep"].post;
assert.ok(submitOperation.requestBody.content["application/json"]);
assert.equal(submitOperation.requestBody.content["multipart/form-data"], undefined);
const fullRequest = openApi.components.schemas.FullPredRequest;
assert.ok(fullRequest.required.includes("nodes"));
assert.ok(fullRequest.required.includes("node_id_field"));

// This malformed request must stop at FastAPI validation and cannot enqueue a job.
const validationResponse = await request("/api/pred/pred_deep", {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: "{}",
});
assert.equal(validationResponse.status, 422);
const validation = await validationResponse.json();
assert.ok(Array.isArray(validation.detail));
assert.ok(validation.detail.some((item) => item.loc?.includes("nodes")));
assert.ok(validation.detail.some((item) => item.loc?.includes("node_id_field")));

console.log(`DeepPipe live API contract checks passed (${baseUrl}, device=${health.device || "unknown"}).`);
