import assert from "node:assert/strict";

const baseUrl = String(process.env.DEEPPIPE_API_BASE_URL || "https://lab.yyworkshop.com/predapi").replace(/\/+$/, "");
const passBaseUrl = String(process.env.DEEPPIPE_PASS_API_BASE_URL || "https://lab.yyworkshop.com").replace(/\/+$/, "");

async function request(path, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20_000);
  try {
    return await fetch(baseUrl + path, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

async function passRequest(path, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20_000);
  try {
    return await fetch(passBaseUrl + path, { ...options, signal: controller.signal });
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
assert.ok(openApi.paths["/api/jobs/jobs/{task_id}/download"]?.get);

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

const variablesResponse = await passRequest("/api/pypass/variables");
assert.equal(variablesResponse.status, 200);
const variables = await variablesResponse.json();
assert.ok(Array.isArray(variables.variables));
for (const id of ["ph", "resistivity", "chloride"]) {
  const variable = variables.variables.find((item) => item.id === id);
  assert.ok(variable?.tile_url?.includes("{z}"));
}

const layerOptionsResponse = await passRequest("/api/pypass/service-life-layer/options");
assert.equal(layerOptionsResponse.status, 200);
const layerOptions = await layerOptionsResponse.json();
assert.ok(Array.isArray(layerOptions.materials) && layerOptions.materials.length >= 7);
assert.ok(String(layerOptions.tile_url).includes("{material_id}"));

const assessmentResponse = await passRequest("/api/pypass/service-life", {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({
    latitude: 34.2104,
    longitude: -77.8868,
    nominal_diameter_cast_iron: 16,
    location_id: "qfield-contract-check",
  }),
});
assert.equal(assessmentResponse.status, 200);
const assessment = await assessmentResponse.json();
assert.equal(assessment.location?.id, "qfield-contract-check");
assert.ok(assessment.soil && "ph" in assessment.soil && "resistivity_ohm_cm" in assessment.soil);
assert.ok(Array.isArray(assessment.service_life?.gauge_materials));
assert.ok(Array.isArray(assessment.warnings));

console.log(`DeepPipe live API contract checks passed (${baseUrl}, PyPASS=${passBaseUrl}, device=${health.device || "unknown"}).`);
