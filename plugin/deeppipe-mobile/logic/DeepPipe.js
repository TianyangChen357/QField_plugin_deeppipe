/*
 * Pure JavaScript used by the QField QML plugin.
 *
 * Keep this file free of QML-only syntax so it can also be exercised with the
 * lightweight Node test harness in tests/.
 */

function predictionDefaults() {
    return {
        workflow_type: "progressive",
        model_type: "progressive_gnn",
        // Display compatibility only. Progressive selection is done by the API.
        classification_threshold: 0.5,
        progressive_config: {
            neighbors_per_sector: 2,
            knn_k: 12,
            knn_max_distance_ft: 250,
            rounds: 3,
            use_msf: true
        }
    };
}

function clamp(value, minimum, maximum) {
    return Math.min(maximum, Math.max(minimum, value));
}

function asFiniteNumber(value, fallback) {
    var parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
}

function normalizePredictionConfig(input) {
    var source = input && input.progressive_config || {};
    var defaults = predictionDefaults();
    var base = defaults.progressive_config;
    defaults.progressive_config = {
        neighbors_per_sector: Math.round(clamp(asFiniteNumber(source.neighbors_per_sector, base.neighbors_per_sector), 1, 8)),
        knn_k: Math.round(clamp(asFiniteNumber(source.knn_k, base.knn_k), 1, 50)),
        knn_max_distance_ft: clamp(asFiniteNumber(source.knn_max_distance_ft, base.knn_max_distance_ft), 1, 5000),
        rounds: Math.round(clamp(asFiniteNumber(source.rounds, base.rounds), 1, 10)),
        use_msf: typeof source.use_msf === "boolean" ? source.use_msf : base.use_msf
    };
    return defaults;
}

function isValidNodeId(value) {
    if (typeof value === "string") {
        return value.trim().length > 0;
    }
    return typeof value === "number" && Number.isInteger(value) && Number.isFinite(value);
}

function stringList(values) {
    var result = [];
    if (!values || typeof values.length !== "number") return result;
    for (var index = 0; index < values.length; index += 1) {
        var value = String(values[index] === undefined || values[index] === null ? "" : values[index]).trim();
        if (value && result.indexOf(value) < 0) result.push(value);
    }
    return result;
}

function projectKey(projectPath, projectName) {
    var path = String(projectPath || "").trim();
    if (path) return "path:" + path;
    var name = String(projectName || "Untitled QField project").trim();
    return "title:" + (name || "Untitled QField project");
}

function parseProjectMappings(text) {
    var parsed = tryParseJson(text);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
    return parsed;
}

function projectMapping(text, projectPath, projectName) {
    var mappings = parseProjectMappings(text);
    var mapping = mappings[projectKey(projectPath, projectName)];
    return mapping && typeof mapping === "object" && !Array.isArray(mapping) ? mapping : null;
}

function updateProjectMapping(text, projectPath, projectName, mapping) {
    var mappings = parseProjectMappings(text);
    var normalized = {
        layer_id: String(mapping && mapping.layer_id || ""),
        layer_name: String(mapping && mapping.layer_name || ""),
        node_id_field: String(mapping && mapping.node_id_field || ""),
        confirmed_at: String(mapping && mapping.confirmed_at || new Date().toISOString())
    };
    mappings[projectKey(projectPath, projectName)] = normalized;
    return JSON.stringify(mappings);
}

function projectServiceSettings(text, projectPath, projectName) {
    var settingsByProject = parseProjectMappings(text);
    var settings = settingsByProject[projectKey(projectPath, projectName)];
    return settings && typeof settings === "object" && !Array.isArray(settings) ? settings : null;
}

function updateProjectServiceSettings(text, projectPath, projectName, settings) {
    var settingsByProject = parseProjectMappings(text);
    var source = settings || {};
    settingsByProject[projectKey(projectPath, projectName)] = {
        prediction_config: normalizePredictionConfig(source.prediction_config)
    };
    return JSON.stringify(settingsByProject);
}

function predictionResultState(text, projectPath, projectName) {
    var resultsByProject = parseProjectMappings(text);
    var state = resultsByProject[projectKey(projectPath, projectName)];
    return state && typeof state === "object" && !Array.isArray(state) ? state : null;
}

function cloneJson(value) {
    return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

function updatePredictionResultState(text, projectPath, projectName, state) {
    var resultsByProject = parseProjectMappings(text);
    var key = projectKey(projectPath, projectName);
    if (!state || (!String(state.path || "").trim() && !String(state.job_id || "").trim())) {
        delete resultsByProject[key];
        return JSON.stringify(resultsByProject);
    }
    var workflow = String(state.workflow_type || (state.input_nodes ? "progressive" : "legacy"));
    var saved = {
        schema_version: 2,
        path: String(state.path || ""),
        layer_name: String(state.layer_name || "DeepPipe Prediction Results"),
        job_id: String(state.job_id || ""),
        parent_job_id: String(state.parent_job_id || ""),
        threshold: asFiniteNumber(state.threshold, predictionDefaults().classification_threshold),
        selected_count: Math.max(0, Math.round(asFiniteNumber(state.selected_count, 0))),
        saved_at: String(state.saved_at || new Date().toISOString()),
        prediction_config: workflow === "progressive" ? normalizePredictionConfig(state.prediction_config) : cloneJson(state.prediction_config || null),
        node_id_field: String(state.node_id_field || "node_id"),
        api_base_url: normalizeApiBaseUrl(state.api_base_url),
        workflow_type: workflow
    };
    ["input_nodes", "candidates", "input_points", "result_summary"].forEach(function (name) {
        if (state[name] !== undefined) saved[name] = cloneJson(state[name]);
    });
    saved.observations = normalizeObservations(state.observations);
    saved.draft_observations = normalizeObservations(state.draft_observations === undefined
                                                    ? saved.observations : state.draft_observations);
    resultsByProject[key] = saved;
    return JSON.stringify(resultsByProject);
}

// IDs are stringified exactly as the API does: numeric 7 and text "7" refer
// to the same original node; leading zeroes and whitespace are preserved.
function canonicalNodePair(nodeU, nodeV) {
    if (!isValidNodeId(nodeU) || !isValidNodeId(nodeV)) {
        throw new Error("Observation node IDs must be nonempty text or integers.");
    }
    var u = String(nodeU);
    var v = String(nodeV);
    if (u === v) throw new Error("A node cannot connect to itself: " + u + ".");
    if (u > v) { var swap = u; u = v; v = swap; }
    return { node_u: u, node_v: v, key: JSON.stringify([u, v]) };
}

function observationNodeIndex(nodes, nodeIdField) {
    var result = Object.create(null);
    var rows = Array.isArray(nodes) ? nodes : nodes && Array.isArray(nodes.features) ? nodes.features : [];
    rows.forEach(function (node) {
        var id = node && node.properties ? node.properties[String(nodeIdField || "node_id")]
               : node && node.nodeId !== undefined ? node.nodeId : node;
        if (!isValidNodeId(id)) throw new Error("Original input contains an invalid node ID.");
        var key = String(id);
        if (result[key] !== undefined) throw new Error("Original input contains duplicate node ID: " + key + ".");
        result[key] = node;
    });
    return result;
}

function normalizeObservations(input, nodes, nodeIdField) {
    if (input === undefined || input === null) input = [];
    if (!Array.isArray(input)) throw new Error("Observations must be a list of node pairs and states.");
    var known = nodes === undefined || nodes === null ? null : observationNodeIndex(nodes, nodeIdField);
    var pairs = Object.create(null);
    input.forEach(function (item) {
        if (!item || typeof item !== "object" || Array.isArray(item)) throw new Error("Each observation needs node_u, node_v, and state.");
        var pair = canonicalNodePair(item.node_u, item.node_v);
        if (item.state !== "connected" && item.state !== "disconnected") throw new Error("Observation state must be connected or disconnected.");
        if (known && (known[pair.node_u] === undefined || known[pair.node_v] === undefined)) {
            throw new Error("Observation refers to an unknown original node.");
        }
        if (pairs[pair.key] && pairs[pair.key].state !== item.state) throw new Error("A connection cannot be both confirmed and rejected.");
        pairs[pair.key] = { node_u: pair.node_u, node_v: pair.node_v, state: item.state };
    });
    return Object.keys(pairs).sort().map(function (key) { return pairs[key]; });
}

function setObservation(snapshot, nodeU, nodeV, state, nodes, nodeIdField) {
    var pair = canonicalNodePair(nodeU, nodeV);
    if (["connected", "disconnected", "unknown"].indexOf(state) < 0) throw new Error("Choose connected, disconnected, or unknown.");
    // Validate the target even when removing an observation.
    if (nodes !== undefined && nodes !== null) {
        var known = observationNodeIndex(nodes, nodeIdField);
        if (known[pair.node_u] === undefined || known[pair.node_v] === undefined) throw new Error("Observation refers to an unknown original node.");
    }
    var next = normalizeObservations(snapshot, nodes, nodeIdField).filter(function (item) {
        return canonicalNodePair(item.node_u, item.node_v).key !== pair.key;
    });
    if (state !== "unknown") next.push({ node_u: pair.node_u, node_v: pair.node_v, state: state });
    return normalizeObservations(next, nodes, nodeIdField);
}

function observationState(snapshot, nodeU, nodeV) {
    var pair = canonicalNodePair(nodeU, nodeV);
    var rows = normalizeObservations(snapshot);
    for (var i = 0; i < rows.length; i += 1) {
        if (canonicalNodePair(rows[i].node_u, rows[i].node_v).key === pair.key) return rows[i].state;
    }
    return "unknown";
}

function resetObservations(saved) { return normalizeObservations(saved); }
function clearObservations() { return []; }
function observationsEqual(first, second) { return JSON.stringify(normalizeObservations(first)) === JSON.stringify(normalizeObservations(second)); }
function undoObservation(history, current) {
    var entries = Array.isArray(history) ? history.slice() : [];
    return { observations: entries.length ? normalizeObservations(entries.pop()) : normalizeObservations(current), history: entries };
}

function observationFeatureCollection(nodes, snapshot, nodeIdField) {
    var index = observationNodeIndex(nodes, nodeIdField);
    var observations = normalizeObservations(snapshot, nodes, nodeIdField);
    function coordinates(node) {
        var position = node && node.geometry && node.geometry.type === "Point" ? node.geometry.coordinates
                     : node && node.longitude !== undefined && node.latitude !== undefined ? [node.longitude, node.latitude]
                     : node ? [node.x, node.y] : [];
        if (!Array.isArray(position) || position.length < 2 || position[0] === null || position[1] === null ||
                !Number.isFinite(Number(position[0])) || !Number.isFinite(Number(position[1]))) {
            throw new Error("Observed connection needs valid original point geometry.");
        }
        return [Number(position[0]), Number(position[1])];
    }
    return {
        type: "FeatureCollection",
        crs: cloneJson(nodes && nodes.crs),
        features: observations.map(function (item) {
            var pair = canonicalNodePair(item.node_u, item.node_v);
            return {
                type: "Feature", id: pair.key,
                properties: { edge_id: pair.key, node_u: pair.node_u, node_v: pair.node_v,
                              state: item.state, observation: item.state === "connected" ? 1 : 0,
                              effective_prob: item.state === "connected" ? 1 : 0 },
                geometry: { type: "LineString", coordinates: [coordinates(index[pair.node_u]), coordinates(index[pair.node_v])] }
            };
        })
    };
}

function createObservationEdge(nodes, nodeU, nodeV, state, nodeIdField) {
    return observationFeatureCollection(nodes, [{node_u: nodeU, node_v: nodeV, state: state}], nodeIdField).features[0];
}

function observationRows(candidates, snapshot) {
    var features = Array.isArray(candidates) ? candidates : candidates && Array.isArray(candidates.features) ? candidates.features : [];
    var states = normalizeObservations(snapshot);
    var stateIndex = Object.create(null);
    states.forEach(function (item) { stateIndex[canonicalNodePair(item.node_u, item.node_v).key] = item.state; });
    var rows = [];
    var seen = Object.create(null);
    features.forEach(function (feature) {
        var p = feature && feature.properties || feature || {};
        var pair = canonicalNodePair(p.node_u, p.node_v);
        if (seen[pair.key]) return;
        seen[pair.key] = true;
        var probability = predictionModelProbability(p);
        rows.push({ edge_id: pair.key, node_u: pair.node_u, node_v: pair.node_v,
                    state: stateIndex[pair.key] || "unknown",
                    selected: Number(p.class) === 1, model_prob: Number.isFinite(probability) ? probability : null });
    });
    states.forEach(function (item) {
        var pair = canonicalNodePair(item.node_u, item.node_v);
        if (!seen[pair.key]) rows.push({edge_id: pair.key, node_u: pair.node_u, node_v: pair.node_v,
                                      state: item.state, selected: false, model_prob: null});
    });
    return rows;
}

function mergeObservationCandidates(candidates, nodes, snapshot, nodeIdField) {
    var collection = cloneJson(candidates || {type: "FeatureCollection", features: []});
    if (!Array.isArray(collection.features)) collection.features = [];
    var existing = Object.create(null);
    collection.features.forEach(function (feature) {
        var p = feature.properties || {};
        existing[canonicalNodePair(p.node_u, p.node_v).key] = true;
    });
    observationFeatureCollection(nodes, snapshot, nodeIdField).features.forEach(function (feature) {
        if (!existing[feature.properties.edge_id]) collection.features.push(feature);
    });
    return collection;
}

function mergePointRecords(currentRecords, incomingRecords) {
    var current = Array.isArray(currentRecords) ? currentRecords : [];
    var incoming = Array.isArray(incomingRecords) ? incomingRecords : [];
    var merged = current.slice();
    var seen = {};
    var added = 0;

    current.forEach(function (record) {
        if (record && Number.isFinite(Number(record.fid))) seen[String(record.fid)] = true;
    });
    incoming.forEach(function (record) {
        if (!record || !Number.isFinite(Number(record.fid))) return;
        var key = String(record.fid);
        if (seen[key]) return;
        seen[key] = true;
        merged.push(record);
        added += 1;
    });
    return { records: merged, added: added };
}

function validateSelectedPoints(points) {
    var rows = Array.isArray(points) ? points : [];
    var errors = [];
    var warnings = [];
    var seenIds = Object.create(null);
    var duplicateIds = Object.create(null);
    var seenCoordinates = Object.create(null);
    var duplicateCoordinateFids = [];

    if (rows.length < 4) {
        errors.push({
            code: "TOO_FEW_INLETS",
            message: "Select at least 4 valid inlet points."
        });
    }

    rows.forEach(function (point) {
        var fid = point && point.fid !== undefined ? point.fid : "unknown";
        var nodeId = point ? point.nodeId : undefined;
        var nodeKey = String(nodeId);
        var x = Number(point && point.x);
        var y = Number(point && point.y);

        if (!isValidNodeId(nodeId)) {
            errors.push({
                code: "INVALID_NODE_ID",
                message: "Selected inlet " + fid + " has an empty or unsupported node ID.",
                feature_ids: [fid]
            });
        } else if (seenIds[nodeKey] !== undefined) {
            duplicateIds[nodeKey] = [seenIds[nodeKey], fid];
        } else {
            seenIds[nodeKey] = fid;
        }

        if (!Number.isFinite(x) || !Number.isFinite(y)) {
            errors.push({
                code: "INVALID_GEOMETRY",
                message: "Selected inlet " + fid + " has invalid point geometry.",
                feature_ids: [fid]
            });
        } else {
            var coordinateKey = x.toFixed(9) + "," + y.toFixed(9);
            if (seenCoordinates[coordinateKey] !== undefined) {
                duplicateCoordinateFids.push(seenCoordinates[coordinateKey], fid);
            } else {
                seenCoordinates[coordinateKey] = fid;
            }
        }
    });

    Object.keys(duplicateIds).forEach(function (nodeId) {
        errors.push({
            code: "DUPLICATE_NODE_ID",
            message: "More than one selected inlet uses node ID '" + nodeId + "'.",
            feature_ids: duplicateIds[nodeId]
        });
    });

    if (duplicateCoordinateFids.length > 0) {
        warnings.push({
            code: "DUPLICATE_COORDINATES",
            message: "Two or more selected inlets share the same coordinates.",
            feature_ids: duplicateCoordinateFids
        });
    }

    return {
        ok: errors.length === 0,
        errors: errors,
        warnings: warnings,
        count: rows.length
    };
}

function featureCollectionFromPoints(points, nodeIdField) {
    var idField = String(nodeIdField || "node_id");
    var rows = Array.isArray(points) ? points : [];
    var features = rows.map(function (point, index) {
        var longitude = Number(point && point.longitude);
        var latitude = Number(point && point.latitude);
        var properties = {};
        properties[idField] = point ? point.nodeId : null;
        properties.source_fid = point && point.fid !== undefined ? Number(point.fid) : index;
        return {
            type: "Feature",
            id: properties.source_fid,
            properties: properties,
            geometry: {
                type: "Point",
                coordinates: [
                    Number(longitude.toFixed(8)),
                    Number(latitude.toFixed(8))
                ]
            }
        };
    });

    return {
        type: "FeatureCollection",
        crs: {
            type: "name",
            properties: { name: "EPSG:4326" }
        },
        features: features
    };
}

function validateLiveSelectedPoints(points) {
    var base = validateSelectedPoints(points);
    var errors = base.errors.slice();
    (Array.isArray(points) ? points : []).forEach(function (point) {
        var longitude = Number(point && point.longitude);
        var latitude = Number(point && point.latitude);
        if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180 ||
                !Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
            errors.push({
                code: "INVALID_WGS84_GEOMETRY",
                message: "Selected inlet " + (point && point.fid !== undefined ? point.fid : "unknown") +
                         " could not be transformed to WGS 84.",
                feature_ids: point && point.fid !== undefined ? [point.fid] : []
            });
        }
    });
    return {
        ok: errors.length === 0,
        errors: errors,
        warnings: base.warnings,
        count: base.count
    };
}

function distanceSquared(a, b) {
    var dx = Number(a.x) - Number(b.x);
    var dy = Number(a.y) - Number(b.y);
    return dx * dx + dy * dy;
}

function distanceBetween(a, b) {
    var lat1 = Number(a && a.latitude);
    var lon1 = Number(a && a.longitude);
    var lat2 = Number(b && b.latitude);
    var lon2 = Number(b && b.longitude);
    if (Number.isFinite(lat1) && Number.isFinite(lon1) &&
            Number.isFinite(lat2) && Number.isFinite(lon2)) {
        var radians = Math.PI / 180;
        var dLat = (lat2 - lat1) * radians;
        var dLon = (lon2 - lon1) * radians;
        var sinLat = Math.sin(dLat / 2);
        var sinLon = Math.sin(dLon / 2);
        var haversine = sinLat * sinLat +
                Math.cos(lat1 * radians) * Math.cos(lat2 * radians) * sinLon * sinLon;
        var earthRadiusFeet = 20902231;
        return 2 * earthRadiusFeet * Math.asin(Math.min(1, Math.sqrt(haversine)));
    }
    return Math.sqrt(distanceSquared(a, b));
}

function stableHash(text) {
    var value = 2166136261;
    var stringValue = String(text || "");
    for (var index = 0; index < stringValue.length; index += 1) {
        value ^= stringValue.charCodeAt(index);
        value = Math.imul(value, 16777619);
    }
    return value >>> 0;
}

function buildMinimumSpanningEdges(points) {
    if (!Array.isArray(points) || points.length < 2) {
        return [];
    }

    var connected = [0];
    var remaining = [];
    var edges = [];
    var index;
    for (index = 1; index < points.length; index += 1) {
        remaining.push(index);
    }

    while (remaining.length > 0) {
        var best = null;
        connected.forEach(function (fromIndex) {
            remaining.forEach(function (toIndex) {
                var distance = distanceBetween(points[fromIndex], points[toIndex]);
                if (!best || distance < best.distance ||
                        (distance === best.distance && toIndex < best.toIndex)) {
                    best = {
                        fromIndex: fromIndex,
                        toIndex: toIndex,
                        distance: distance
                    };
                }
            });
        });

        edges.push({
            from: points[best.fromIndex],
            to: points[best.toIndex],
            distance: best.distance,
            projectDistance: Math.sqrt(distanceSquared(points[best.fromIndex], points[best.toIndex]))
        });
        connected.push(best.toIndex);
        remaining.splice(remaining.indexOf(best.toIndex), 1);
    }
    return edges;
}

function createMockJobId(points, nowValue) {
    var nodePart = (points || []).map(function (point) {
        return String(point.nodeId);
    }).sort().join("|");
    var stamp = Math.floor(asFiniteNumber(nowValue, Date.now()) / 1000).toString(36);
    return "mock-" + stamp + "-" + stableHash(nodePart).toString(36).slice(0, 6);
}

function buildMockPrediction(points, inputConfig, jobId) {
    var validation = validateSelectedPoints(points);
    if (!validation.ok) {
        return {
            ok: false,
            validation: validation,
            featureCollection: { type: "FeatureCollection", features: [] },
            summary: { total: 0, predicted: 0, potential: 0, unknown: 0 }
        };
    }

    var config = normalizePredictionConfig(inputConfig);
    var edges = buildMinimumSpanningEdges(points);
    var predicted = 0;
    var potential = 0;
    var excluded = 0;

    var features = edges.map(function (edge, index) {
        var distanceRatio = clamp(edge.distance / config.progressive_config.knn_max_distance_ft, 0, 1.5);
        var pairKey = String(edge.from.nodeId) + "|" + String(edge.to.nodeId);
        var hashAdjustment = (stableHash(pairKey) % 9) / 100;
        var probability = clamp(0.96 - distanceRatio * 0.28 + hashAdjustment, 0.51, 0.98);
        var withinRadius = edge.distance <= config.progressive_config.knn_max_distance_ft;
        var modelClass = withinRadius && probability >= config.classification_threshold ? 1 : 0;
        var resultType = modelClass === 1 ? "predicted" : "excluded";
        if (modelClass === 1) {
            predicted += 1;
        } else {
            excluded += 1;
        }

        return {
            type: "Feature",
            id: "mock-pipe-" + (index + 1),
            properties: {
                pipe_id: "MP-" + String(index + 1).padStart(3, "0"),
                node_u: String(edge.from.nodeId),
                node_v: String(edge.to.nodeId),
                source_fid: Number(edge.from.fid),
                target_fid: Number(edge.to.fid),
                distance_ft: Number(edge.distance.toFixed(1)),
                distance_project_units: Number(edge.projectDistance.toFixed(6)),
                within_search_radius: withinRadius ? 1 : 0,
                prob: Number(probability.toFixed(4)),
                model_class: modelClass,
                class: modelClass,
                result_type: resultType,
                review_status: "unreviewed",
                job_id: jobId || "mock",
                analysis_mode: "mock_preview"
            },
            geometry: {
                type: "LineString",
                coordinates: [
                    [Number(edge.from.x), Number(edge.from.y)],
                    [Number(edge.to.x), Number(edge.to.y)]
                ]
            }
        };
    });

    return {
        ok: true,
        validation: validation,
        featureCollection: {
            type: "FeatureCollection",
            features: features
        },
        summary: {
            total: predicted + potential,
            predicted: predicted,
            potential: potential,
            unknown: 0,
            excluded: excluded,
            selectedInlets: points.length,
            threshold: config.classification_threshold
        },
        config: config
    };
}

function buildPredictionRequest(featureCollection, nodeIdField, inputConfig, context) {
    var config = normalizePredictionConfig(inputConfig);
    return {
        nodes: featureCollection,
        node_id_field: String(nodeIdField || "node_id"),
        workflow_type: "progressive",
        model_type: "progressive_gnn",
        progressive_config: cloneJson(config.progressive_config)
    };
}

function buildRefinementRequest(observations, nodes, nodeIdField) {
    return { observations: normalizeObservations(observations, nodes, nodeIdField) };
}

function normalizeApiBaseUrl(value) {
    var url = String(value || "").trim();
    while (url.length > 0 && url.charAt(url.length - 1) === "/") {
        url = url.slice(0, -1);
    }
    if (!/^https?:\/\//i.test(url)) {
        return "";
    }
    return url;
}

function apiUrl(baseUrl, path) {
    var base = normalizeApiBaseUrl(baseUrl);
    var suffix = String(path || "");
    if (!base) return "";
    if (suffix && suffix.charAt(0) !== "/") suffix = "/" + suffix;
    return base + suffix;
}

function resolveCatalogUrl(baseUrl, value) {
    var url = String(value || "").trim();
    if (/^https?:\/\//i.test(url)) return url;
    var base = normalizeApiBaseUrl(baseUrl);
    if (!base || !url) return "";
    if (url.charAt(0) === "/") {
        var origin = base.match(/^(https?:\/\/[^/]+)/i);
        return origin ? origin[1] + url : "";
    }
    return apiUrl(base, url);
}

function normalizeHttpsUrl(value) {
    var url = String(value || "").trim();
    if (!/^https:\/\/[^\s]+$/i.test(url)) return "";
    return url;
}

function pypassTileTransportUrl(value) {
    var url = String(value || "").trim();
    // The current public portal intercepts literal .png tile paths before they
    // reach FastAPI. Encoding only the terminal dot preserves the documented
    // route while allowing the request to pass through the proxy unchanged.
    if (!/^https:\/\/lab\.yyworkshop\.com\/api\/pypass\//i.test(url)) return url;
    return url.replace(/\.png(?=([?#]|$))/i, "%2Epng");
}

function xyzRasterUri(value, minimumZoom, maximumZoom) {
    var url = normalizeHttpsUrl(value);
    if (!url) return "";
    var encodedUrl = url
            .replace(/%/g, "%25")
            .replace(/\{/g, "%7B")
            .replace(/\}/g, "%7D")
            .replace(/\?/g, "%3F")
            .replace(/&/g, "%26")
            .replace(/=/g, "%3D");
    return "type=xyz&tilePixelRatio=1&url=" + encodedUrl +
            "&zmax=" + Math.round(asFiniteNumber(maximumZoom, 19)) +
            "&zmin=" + Math.round(asFiniteNumber(minimumZoom, 4)) +
            "&crs=EPSG3857";
}

function appendUrlQuery(value, query) {
    var url = String(value || "");
    var suffix = String(query || "").replace(/^[?&]+/, "");
    if (!url || !suffix) return url;
    if (/[?&]$/.test(url)) return url + suffix;
    return url + (url.indexOf("?") >= 0 ? "&" : "?") + suffix;
}

function safeFilePart(value, fallback) {
    var cleaned = String(value || "")
            .replace(/[^A-Za-z0-9._-]+/g, "-")
            .replace(/^-+|-+$/g, "")
            .slice(0, 80);
    return cleaned || String(fallback || "result");
}

function tryParseJson(text) {
    if (text && typeof text === "object") return text;
    var source = String(text || "").trim();
    if (!source) return null;
    try {
        return JSON.parse(source);
    } catch (error) {
        return null;
    }
}

function apiErrorMessage(payload, status, fallbackText) {
    var data = payload || {};
    var fallback = String(fallbackText || "").trim();
    if (Array.isArray(data.detail)) {
        var validationMessages = data.detail.map(function (item) {
            var location = item && Array.isArray(item.loc) ? item.loc.slice(1).join(".") : "request";
            var message = item && item.msg ? String(item.msg) : "Invalid value";
            return (location || "request") + ": " + message;
        });
        if (validationMessages.length > 0) return validationMessages.join("; ");
    }
    if (data.detail && typeof data.detail === "object") {
        var detailMessage = String(data.detail.message || data.detail.error || "");
        var suggestion = String(data.detail.suggestion || "");
        if (detailMessage && suggestion) return detailMessage + " " + suggestion;
        if (detailMessage) return detailMessage;
    }
    if (typeof data.detail === "string" && data.detail) return data.detail;
    if (data.error && typeof data.error === "object" && data.error.message) return String(data.error.message);
    if (typeof data.error === "string" && data.error) return data.error;
    if (data.message) return String(data.message);
    if (fallback) return fallback;
    return status ? "DeepPipe API returned HTTP " + status + "." : "DeepPipe API could not be reached.";
}

function choosePipeResultFilename(files) {
    var names = Array.isArray(files) ? files.map(function (value) {
        if (value && typeof value === "object") {
            value = value.name || value.filename || value.path || value.url || "";
        }
        var normalized = String(value || "").split(/[?#]/)[0].replace(/\\/g, "/");
        return normalized.slice(normalized.lastIndexOf("/") + 1);
    }).filter(function (value) { return value.length > 0; }) : [];
    var exact = names.find(function (name) { return name.toLowerCase() === "pipes.geojson"; });
    if (exact) return exact;
    var pipeGeoJson = names.find(function (name) {
        var lower = name.toLowerCase();
        return lower.endsWith(".geojson") && lower.indexOf("pipe") >= 0;
    });
    return pipeGeoJson || "";
}

function predictionNumericProperty(properties, names) {
    var source = properties || {};
    for (var index = 0; index < names.length; index += 1) {
        var value = source[names[index]];
        if (value === undefined || value === null || value === "") continue;
        var number = Number(value);
        if (Number.isFinite(number)) return number;
    }
    return NaN;
}

function predictionResultType(feature, threshold) {
    var properties = feature && feature.properties ? feature.properties : {};
    // The API's class is the final constrained network selection. A confirmed
    // pipe can have a low raw neural probability and must still be displayed.
    var finalClass = predictionNumericProperty(properties, ["class"]);
    if (finalClass === 1) return "predicted";
    if (finalClass === 0) {
        // Historical results can explicitly retain the previous display mode.
        var legacy = properties.workflow_type === "legacy" || properties.analysis_mode === "legacy";
        var probability = predictionNumericProperty(properties, ["prob", "probability", "score"]);
        return legacy && Number(properties.model_class) === 1 && probability >= Number(threshold) ? "potential" : "excluded";
    }
    var explicitType = String(properties.deeppipe_outcome || properties.result_type || properties.display_class || "").toLowerCase();
    if (["predicted", "positive", "accepted", "class_1"].indexOf(explicitType) >= 0) return "predicted";
    if (["potential", "rejected", "class_0", "negative", "below_threshold", "excluded", "candidate", "model_0"].indexOf(explicitType) >= 0) return "excluded";
    return "unknown";
}

function predictionModelProbability(properties) {
    var source = properties || {};
    if (source.model_prob !== undefined || source.neural_probability !== undefined) {
        return predictionNumericProperty(source, ["model_prob", "neural_probability"]);
    }
    var observation = source.observation;
    var state = source.observation_state || source.state;
    if (observation === 0 || observation === 1 || observation === "connected" || observation === "disconnected" ||
            state === "connected" || state === "disconnected") return NaN;
    return predictionNumericProperty(source, ["prob", "probability", "score"]);
}

function effectivePredictionProperties(properties) {
    var source = properties || {};
    var copy = cloneJson(source);
    var raw = predictionModelProbability(source);
    if (Number.isFinite(raw)) copy.model_prob = raw;
    var effective = predictionNumericProperty(source, ["effective_prob", "effective_probability", "prob", "probability", "score"]);
    var observed = source.observation;
    var state = source.observation_state || source.state;
    if (observed === 1 || observed === "connected" || state === "connected") effective = 1;
    if (observed === 0 || observed === "disconnected" || state === "disconnected") effective = 0;
    if (Number.isFinite(effective)) {
        copy.prob = effective;
        copy.effective_prob = effective;
        copy.effective_probability = effective;
    }
    return copy;
}

function predictionResultColor(resultType) {
    if (resultType === "predicted") return "#005035";
    if (resultType === "potential") return "#F4C430";
    return "#64748b";
}

function partitionPredictionResults(featureCollection, threshold) {
    var source = featureCollection || {};
    var predicted = [];
    var potential = [];
    var unknown = [];
    var excluded = [];
    (Array.isArray(source.features) ? source.features : []).forEach(function (feature) {
        var resultType = predictionResultType(feature, threshold);
        var copy = {
            type: feature.type || "Feature",
            geometry: feature.geometry,
            properties: {}
        };
        if (feature.id !== undefined) copy.id = feature.id;
        var properties = effectivePredictionProperties(feature.properties || {});
        Object.keys(properties).forEach(function (key) { copy.properties[key] = properties[key]; });
        copy.properties.result_type = resultType;
        copy.properties.display_class = resultType;
        copy.properties.deeppipe_outcome = resultType;
        copy.properties.deeppipe_color = predictionResultColor(resultType);
        if (resultType === "potential") potential.push(copy);
        else if (resultType === "predicted") predicted.push(copy);
        else if (resultType === "excluded") excluded.push(copy);
        else unknown.push(copy);
    });

    function collection(features) {
        return {
            type: "FeatureCollection",
            crs: source.crs,
            features: features
        };
    }
    return {
        predicted: collection(predicted),
        potential: collection(potential),
        unknown: collection(unknown),
        excluded: collection(excluded),
        predictedCount: predicted.length,
        potentialCount: potential.length,
        unknownCount: unknown.length,
        excludedCount: excluded.length,
        total: predicted.length + potential.length,
        returnedTotal: predicted.length + potential.length + unknown.length + excluded.length
    };
}

function decorateLiveResult(featureCollection, jobId, threshold) {
    var source = featureCollection || {};
    var features = Array.isArray(source.features) ? source.features : [];
    var decorated = features.map(function (feature) {
        var copy = {
            type: feature.type || "Feature",
            geometry: feature.geometry,
            properties: {}
        };
        if (feature.id !== undefined) copy.id = feature.id;
        var properties = effectivePredictionProperties(feature.properties || {});
        Object.keys(properties).forEach(function (key) { copy.properties[key] = properties[key]; });
        copy.properties.job_id = String(jobId || "");
        copy.properties.analysis_mode = "live_api";
        copy.properties.review_status = copy.properties.review_status || "unreviewed";
        copy.properties.result_type = predictionResultType(copy, threshold);
        copy.properties.display_class = copy.properties.result_type;
        copy.properties.deeppipe_outcome = copy.properties.result_type;
        copy.properties.deeppipe_color = predictionResultColor(copy.properties.result_type);
        return copy;
    });
    return {
        type: "FeatureCollection",
        crs: source.crs || {
            type: "name",
            properties: { name: "EPSG:4326" }
        },
        features: decorated
    };
}

function summarizeLiveResult(featureCollection, selectedCount, threshold) {
    var partitions = partitionPredictionResults(featureCollection, threshold);
    return {
        total: partitions.total,
        predicted: partitions.predictedCount,
        potential: partitions.potentialCount,
        unknown: partitions.unknownCount,
        excluded: partitions.excludedCount,
        selectedInlets: Number(selectedCount || 0),
        threshold: Number(threshold || 0)
    };
}

function predictionAttributeLabel(key) {
    var labels = {
        __row: "Row",
        deeppipe_outcome: "Outcome",
        node_u: "From inlet",
        node_v: "To inlet",
        prob: "Effective probability",
        model_prob: "Model probability",
        effective_prob: "Effective probability",
        effective_probability: "Effective probability",
        probability: "GNN probability",
        length: "Length (ft)",
        class: "Final selected class",
        model_class: "GNN class"
    };
    return labels[key] || String(key || "");
}

function predictionAttributeTable(featureCollection) {
    var features = featureCollection && Array.isArray(featureCollection.features)
            ? featureCollection.features : [];
    var preferred = [
        "__row", "deeppipe_outcome", "node_u", "node_v", "model_prob", "prob", "length",
        "class", "model_class", "sample_id", "link_id", "job_id"
    ];
    var seen = {};
    var keys = [];
    function addKey(key) {
        var normalized = String(key || "");
        if (!normalized || seen[normalized]) return;
        seen[normalized] = true;
        keys.push(normalized);
    }
    preferred.forEach(addKey);
    features.forEach(function (feature) {
        Object.keys(feature && feature.properties ? feature.properties : {}).sort().forEach(addKey);
    });

    // Do not show preferred placeholders that are absent from every feature.
    keys = keys.filter(function (key) {
        if (key === "__row") return true;
        return features.some(function (feature) {
            var properties = feature && feature.properties ? feature.properties : {};
            return properties[key] !== undefined;
        });
    });

    return {
        columns: keys.map(function (key) { return { key: key, label: predictionAttributeLabel(key) }; }),
        rows: features.map(function (feature, index) {
            var row = { __row: index + 1 };
            var properties = feature && feature.properties ? feature.properties : {};
            Object.keys(properties).forEach(function (key) { row[key] = properties[key]; });
            return row;
        })
    };
}

function featureCollectionMultiLineWkt(featureCollection) {
    var lines = [];
    var features = featureCollection && Array.isArray(featureCollection.features)
            ? featureCollection.features : [];

    function appendLine(coordinates) {
        if (!Array.isArray(coordinates) || coordinates.length < 2) return;
        var points = [];
        coordinates.forEach(function (coordinate) {
            if (!Array.isArray(coordinate) || coordinate.length < 2) return;
            var x = Number(coordinate[0]);
            var y = Number(coordinate[1]);
            if (Number.isFinite(x) && Number.isFinite(y)) points.push(x + " " + y);
        });
        if (points.length >= 2) lines.push("(" + points.join(", ") + ")");
    }

    features.forEach(function (feature) {
        var geometry = feature && feature.geometry ? feature.geometry : {};
        if (geometry.type === "LineString") appendLine(geometry.coordinates);
        else if (geometry.type === "MultiLineString" && Array.isArray(geometry.coordinates)) {
            geometry.coordinates.forEach(appendLine);
        }
    });
    return lines.length > 0 ? "MULTILINESTRING (" + lines.join(", ") + ")" : "";
}

function multiLineWktFromFeatureWkts(wkts) {
    var parts = [];
    var dimension = null;
    var values = Array.isArray(wkts) ? wkts : [];

    for (var index = 0; index < values.length; index += 1) {
        var text = String(values[index] || "").trim();
        var match = text.match(/^\s*(LINESTRING|MULTILINESTRING)\s*(ZM|Z|M)?\s*(\([\s\S]*\))\s*$/i);
        if (!match) continue;

        var nextDimension = String(match[2] || "").toUpperCase();
        if (dimension === null) dimension = nextDimension;
        if (dimension !== nextDimension) return "";

        var body = String(match[3] || "").trim();
        if (body.length < 2 || body[0] !== "(" || body[body.length - 1] !== ")") continue;
        if (String(match[1]).toUpperCase() === "MULTILINESTRING") {
            body = body.slice(1, -1).trim();
            if (!body) continue;
        }
        parts.push(body);
    }

    if (parts.length === 0) return "";
    return "MULTILINESTRING" + (dimension ? " " + dimension : "") +
            " (" + parts.join(", ") + ")";
}

function normalizeJobStatus(value) {
    var status = String(value || "unknown").toLowerCase();
    if (status === "pending") {
        return "queued";
    }
    if (status === "started" || status === "progress") {
        return "running";
    }
    if (status === "success" || status === "completed") {
        return "succeeded";
    }
    if (status === "failure" || status === "error") {
        return "failed";
    }
    if (status === "revoked" || status === "canceled") {
        return "cancelled";
    }
    return status;
}

function statusMessage(payload) {
    var data = payload || {};
    var info = data.info || {};
    if (typeof info === "string") return String(data.message || info);
    return String(data.message || info.step || info.error || info.status || data.detail || "");
}

function chlorideLabel(seed) {
    if (seed < 0.2) return "Low";
    if (seed < 0.45) return "Moderate";
    if (seed < 0.7) return "High";
    if (seed < 0.9) return "Very High";
    return "Extremely High";
}

function passMaterials() {
    return [
        { id: "rcp", name: "RCP", requires_gauge: false, default_gauge: 0, gauge_sizes: [] },
        { id: "cast_iron", name: "Cast Iron", requires_gauge: false, default_gauge: 0, gauge_sizes: [] },
        { id: "plastic", name: "HDPE / PP / PVC", requires_gauge: false, default_gauge: 0, gauge_sizes: [] },
        { id: "galvanized", name: "Galvanized", requires_gauge: true, default_gauge: 16, gauge_sizes: [8, 10, 12, 14, 16, 18] },
        { id: "aluminized_csp", name: "Aluminized CSP", requires_gauge: true, default_gauge: 16, gauge_sizes: [8, 10, 12, 14, 16] },
        { id: "aluminum", name: "Aluminum", requires_gauge: true, default_gauge: 12, gauge_sizes: [8, 10, 12, 14, 16] },
        { id: "steel", name: "Steel", requires_gauge: true, default_gauge: 16, gauge_sizes: [8, 10, 12, 14, 16, 18] }
    ];
}

function passMaterialById(materialId) {
    var id = String(materialId || "");
    return passMaterials().find(function (material) { return material.id === id; }) || passMaterials()[0];
}

function passMaterialOptions() {
    return passMaterials().map(function (material) {
        return {
            id: material.id,
            name: material.name,
            requires_gauge: material.requires_gauge,
            default_gauge: material.default_gauge,
            gauge_sizes: material.gauge_sizes.slice()
        };
    });
}

function passGaugeOptions(materialId) {
    return passMaterialById(materialId).gauge_sizes.slice();
}

function passRasterGauge(materialId, requestedGauge, catalogMaterials) {
    var fallback = passMaterialById(materialId);
    var catalog = (Array.isArray(catalogMaterials) ? catalogMaterials : []).find(function (item) {
        return String(item && item.id || "") === fallback.id;
    }) || {};
    var requiresGauge = typeof catalog.requires_gauge === "boolean"
            ? catalog.requires_gauge : fallback.requires_gauge;
    if (!requiresGauge) {
        return { requiresGauge: false, gauge: 0, requestedGauge: 0, adjusted: false, allowedGauges: [] };
    }
    var allowed = (Array.isArray(catalog.gauge_sizes) ? catalog.gauge_sizes : fallback.gauge_sizes)
            .map(function (value) { return Math.round(Number(value)); })
            .filter(function (value, index, values) {
                return Number.isFinite(value) && value > 0 && values.indexOf(value) === index;
            });
    var requested = Math.round(asFiniteNumber(requestedGauge, fallback.default_gauge));
    var catalogDefault = Math.round(asFiniteNumber(catalog.default_gauge, fallback.default_gauge));
    var selected = allowed.indexOf(requested) >= 0
            ? requested
            : (allowed.indexOf(catalogDefault) >= 0 ? catalogDefault : (allowed[0] || requested));
    return {
        requiresGauge: true,
        gauge: selected,
        requestedGauge: requested,
        adjusted: selected !== requested,
        allowedGauges: allowed
    };
}

function passVariableTilePath(variableId) {
    var id = String(variableId || "").toLowerCase();
    return ["ph", "resistivity", "chloride"].indexOf(id) >= 0
            ? "/api/pypass/tiles/" + id + "/{z}/{x}/{y}.png"
            : "";
}

function passServiceLifeTilePath(materialId, minimumYears, gauge) {
    var material = passMaterialById(materialId);
    var gaugeSelection = passRasterGauge(material.id, gauge, []);
    var years = Math.max(0, Math.round(asFiniteNumber(minimumYears, 0)));
    var path = "/api/pypass/service-life-tiles/" + encodeURIComponent(material.id) +
            "/{z}/{x}/{y}.png?min_years=" + years;
    if (gaugeSelection.requiresGauge) {
        path += "&gauge=" + gaugeSelection.gauge;
    }
    return path;
}

function normalizeLiveAssessment(payload, selectedGauge) {
    var data = payload || {};
    var location = data.location || {};
    var soil = data.soil || {};
    var serviceLife = data.service_life || {};
    var fixed = serviceLife.fixed_materials || {};
    var gaugeRows = Array.isArray(serviceLife.gauge_materials) ? serviceLife.gauge_materials : [];
    var requestedGauge = Math.round(asFiniteNumber(selectedGauge, 16));
    var gaugeRow = gaugeRows.find(function (row) { return Number(row && row.gauge) === requestedGauge; });
    if (!gaugeRow && gaugeRows.length > 0) gaugeRow = gaugeRows[0];
    gaugeRow = gaugeRow || {};
    var gauge = Number.isFinite(Number(gaugeRow.gauge)) ? Number(gaugeRow.gauge) : requestedGauge;

    function estimate(id, name, value, estimateGauge) {
        var years = value === undefined || value === null || value === "" ? NaN : Number(value);
        return {
            id: id,
            name: name,
            years: Number.isFinite(years) ? years : null,
            gauge: estimateGauge || ""
        };
    }

    var latitude = Number(location.latitude);
    var longitude = Number(location.longitude);
    return {
        ok: Number.isFinite(latitude) && Number.isFinite(longitude) &&
                data.soil !== undefined && data.soil !== null &&
                data.service_life !== undefined && data.service_life !== null,
        mode: "live_api",
        location: { latitude: latitude, longitude: longitude },
        nominal_diameter_cast_iron: data.nominal_diameter_cast_iron === undefined || data.nominal_diameter_cast_iron === null || data.nominal_diameter_cast_iron === ""
                ? 16 : asFiniteNumber(data.nominal_diameter_cast_iron, 16),
        soil: {
            ph: soil.ph !== undefined && soil.ph !== null && soil.ph !== "" && Number.isFinite(Number(soil.ph)) ? Number(soil.ph) : null,
            resistivity_ohm_cm: soil.resistivity_ohm_cm !== undefined && soil.resistivity_ohm_cm !== null && soil.resistivity_ohm_cm !== "" && Number.isFinite(Number(soil.resistivity_ohm_cm)) ? Number(soil.resistivity_ohm_cm) : null,
            chloride: soil.chloride === undefined || soil.chloride === null || String(soil.chloride).trim() === ""
                    ? null : String(soil.chloride)
        },
        estimates: [
            estimate("rcp", "RCP", fixed.reinforced_concrete_pipe_rcp_years, ""),
            estimate("cast_iron", "Cast Iron", fixed.cast_iron_pipe_years, ""),
            estimate("plastic", "HDPE / PP / PVC", fixed.plastic_pipes_hdpe_pp_pvc_years, ""),
            estimate("galvanized", "Galvanized", gaugeRow.galvanized_pipe_years, gauge),
            estimate("aluminized_csp", "Aluminized CSP", gaugeRow.aluminized_csp_type_2_pipe_years, gauge),
            estimate("aluminum", "Aluminum", gaugeRow.aluminum_pipe_years, gauge),
            estimate("steel", "Steel", gaugeRow.steel_pipe_years, gauge)
        ],
        warnings: Array.isArray(data.warnings) ? data.warnings.map(function (warning) { return String(warning); }) : []
    };
}

function buildMockAssessment(latitude, longitude, diameter) {
    var lat = asFiniteNumber(latitude, NaN);
    var lon = asFiniteNumber(longitude, NaN);
    var nominalDiameter = asFiniteNumber(diameter, 16);
    if (!Number.isFinite(lat) || lat < -90 || lat > 90 ||
            !Number.isFinite(lon) || lon < -180 || lon > 180) {
        return {
            ok: false,
            error: "Choose a valid map or GNSS location before assessment."
        };
    }

    var seed = (stableHash(lat.toFixed(5) + "|" + lon.toFixed(5)) % 1000) / 1000;
    var ph = Number((5.1 + seed * 2.2).toFixed(1));
    var resistivity = Math.round(450 + seed * 3650);
    var chloride = chlorideLabel(seed);
    var corrosionFactor = clamp((7.5 - ph) * 0.08 + (1500 / resistivity) * 0.12 + seed * 0.12, 0.05, 0.55);
    var diameterFactor = clamp(nominalDiameter / 16, 0.75, 2.5);

    function years(base, multiplier) {
        return Number((base * multiplier * diameterFactor * (1 - corrosionFactor)).toFixed(1));
    }

    return {
        ok: true,
        mode: "mock_preview",
        location: {
            latitude: Number(lat.toFixed(6)),
            longitude: Number(lon.toFixed(6))
        },
        nominal_diameter_cast_iron: nominalDiameter,
        soil: {
            ph: ph,
            resistivity_ohm_cm: resistivity,
            chloride: chloride
        },
        estimates: [
            { id: "rcp", name: "RCP", years: years(92, 1.0), gauge: "" },
            { id: "cast_iron", name: "Cast Iron", years: years(78, 0.96), gauge: "" },
            { id: "plastic", name: "HDPE / PP / PVC", years: years(105, 1.04), gauge: "" },
            { id: "galvanized", name: "Galvanized", years: years(66, 0.88), gauge: "16" },
            { id: "aluminized_csp", name: "Aluminized CSP", years: years(84, 0.94), gauge: "16" },
            { id: "aluminum", name: "Aluminum", years: years(88, 0.98), gauge: "12" },
            { id: "steel", name: "Steel", years: years(72, 0.91), gauge: "16" }
        ]
    };
}
