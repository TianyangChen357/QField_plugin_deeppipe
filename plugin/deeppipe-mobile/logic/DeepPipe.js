/*
 * Pure JavaScript used by the QField QML plugin.
 *
 * Keep this file free of QML-only syntax so it can also be exercised with the
 * lightweight Node test harness in tests/.
 */

function predictionDefaults() {
    return {
        model_type: "gnn",
        max_search_radius: 500,
        road_half_width_ft: 100,
        k_neighbors: 12,
        classification_threshold: 0.85,
        threshold_tolerance: 0.3,
        with_mst: true,
        prob_weight: 0.5,
        elev_weight: 0.0,
        length_weight: 0.5
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
    var source = input || {};
    var defaults = predictionDefaults();
    var config = {
        model_type: String(source.model_type || defaults.model_type).toLowerCase(),
        max_search_radius: clamp(asFiniteNumber(source.max_search_radius, defaults.max_search_radius), 100, 1500),
        road_half_width_ft: Math.max(0, asFiniteNumber(source.road_half_width_ft, defaults.road_half_width_ft)),
        k_neighbors: Math.round(clamp(asFiniteNumber(source.k_neighbors, defaults.k_neighbors), 3, 20)),
        classification_threshold: clamp(asFiniteNumber(source.classification_threshold, defaults.classification_threshold), 0.51, 0.99),
        threshold_tolerance: clamp(asFiniteNumber(source.threshold_tolerance, defaults.threshold_tolerance), 0, 0.5),
        with_mst: source.with_mst === undefined ? defaults.with_mst : Boolean(source.with_mst),
        prob_weight: asFiniteNumber(source.prob_weight, defaults.prob_weight),
        elev_weight: asFiniteNumber(source.elev_weight, defaults.elev_weight),
        length_weight: asFiniteNumber(source.length_weight, defaults.length_weight)
    };

    var weightSum = config.prob_weight + config.elev_weight + config.length_weight;
    if (!Number.isFinite(weightSum) || weightSum <= 0) {
        config.prob_weight = defaults.prob_weight;
        config.elev_weight = defaults.elev_weight;
        config.length_weight = defaults.length_weight;
    } else if (Math.abs(weightSum - 1) > 0.000001) {
        config.prob_weight = config.prob_weight / weightSum;
        config.elev_weight = config.elev_weight / weightSum;
        config.length_weight = config.length_weight / weightSum;
    }
    return config;
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

function suggestedNodeIdField(fieldNames, preferred) {
    var names = stringList(fieldNames);
    var requested = String(preferred || "").trim();
    if (requested && names.indexOf(requested) >= 0) return requested;

    var lowerToOriginal = {};
    names.forEach(function (name) { lowerToOriginal[name.toLowerCase()] = name; });
    var priorities = [
        "inlet_uuid", "node_uuid", "asset_uuid", "uuid",
        "node_id", "inlet_id", "asset_id", "assetid",
        "structure_id", "globalid", "id", "objectid"
    ];
    for (var index = 0; index < priorities.length; index += 1) {
        if (lowerToOriginal[priorities[index]]) return lowerToOriginal[priorities[index]];
    }
    return "";
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
        api_base_url: String(source.api_base_url || ""),
        pypass_api_base_url: String(source.pypass_api_base_url || ""),
        remote_cog_url: String(source.remote_cog_url || ""),
        remote_cog_layer_name: String(source.remote_cog_layer_name || "DeepPipe Remote COG")
    };
    return JSON.stringify(settingsByProject);
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
    var seenIds = {};
    var duplicateIds = {};
    var seenCoordinates = {};
    var duplicateCoordinateFids = [];

    if (rows.length < 3) {
        errors.push({
            code: "TOO_FEW_INLETS",
            message: "Select at least 3 valid inlet points."
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

    var features = edges.map(function (edge, index) {
        var distanceRatio = clamp(edge.distance / config.max_search_radius, 0, 1.5);
        var pairKey = String(edge.from.nodeId) + "|" + String(edge.to.nodeId);
        var hashAdjustment = (stableHash(pairKey) % 9) / 100;
        var probability = clamp(0.96 - distanceRatio * 0.28 + hashAdjustment, 0.51, 0.98);
        var withinRadius = edge.distance <= config.max_search_radius;
        var modelClass = withinRadius && probability >= config.classification_threshold ? 1 : 0;
        var resultType = modelClass === 1 ? "predicted" : "potential";
        if (modelClass === 1) {
            predicted += 1;
        } else {
            potential += 1;
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
            total: features.length,
            predicted: predicted,
            potential: potential,
            unknown: 0,
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
        model_type: config.model_type,
        node_id_field: String(nodeIdField || "node_id"),
        max_search_radius: config.max_search_radius,
        road_half_width_ft: config.road_half_width_ft,
        k_neighbors: config.k_neighbors,
        classification_threshold: config.classification_threshold,
        threshold_tolerance: config.threshold_tolerance,
        with_mst: config.with_mst,
        prob_weight: config.prob_weight,
        elev_weight: config.elev_weight,
        length_weight: config.length_weight
    };
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

function normalizeRemoteRasterUrl(value) {
    var url = String(value || "").trim();
    if (!/^https:\/\/[^\s]+$/i.test(url)) return "";
    return url;
}

function gdalRemoteRasterUri(value) {
    var url = normalizeRemoteRasterUrl(value);
    return url ? "/vsicurl/" + url : "";
}

function xyzRasterUri(value, minimumZoom, maximumZoom) {
    var url = normalizeRemoteRasterUrl(value);
    if (!url) return "";
    var encodedUrl = url
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

function predictionResultType(feature, threshold) {
    var properties = feature && feature.properties ? feature.properties : {};
    var classValue = properties.class;
    if (classValue !== undefined && classValue !== null && classValue !== "") {
        var normalizedClass = Number(classValue);
        if (Number.isFinite(normalizedClass)) {
            if (normalizedClass === 1) return "predicted";
            if (normalizedClass === 0) return "potential";
            return "unknown";
        }
    }

    var connectivity = properties.is_connect;
    if (connectivity !== undefined && connectivity !== null && connectivity !== "") {
        var normalizedConnectivity = Number(connectivity);
        if (Number.isFinite(normalizedConnectivity)) {
            if (normalizedConnectivity === 1) return "predicted";
            if (normalizedConnectivity === 0 || normalizedConnectivity === -1) return "potential";
            return "unknown";
        }
    }

    var probability = properties.prob;
    if (probability === undefined || probability === null || probability === "") probability = properties.probability;
    if (probability === undefined || probability === null || probability === "") probability = properties.score;
    var numericProbability = Number(probability);
    var numericThreshold = Number(threshold);
    if (Number.isFinite(numericProbability) && Number.isFinite(numericThreshold)) {
        return numericProbability >= numericThreshold ? "predicted" : "potential";
    }

    var explicitType = String(properties.deeppipe_outcome || properties.result_type || properties.display_class || "").toLowerCase();
    if (["potential", "negative", "rejected", "below_threshold", "class_0"].indexOf(explicitType) >= 0) {
        return "potential";
    }
    if (["predicted", "positive", "accepted", "class_1"].indexOf(explicitType) >= 0) {
        return "predicted";
    }
    if (explicitType === "unknown") return "unknown";

    var modelClass = properties.model_class;
    if (modelClass !== undefined && modelClass !== null && modelClass !== "") {
        var normalizedModelClass = Number(modelClass);
        if (Number.isFinite(normalizedModelClass)) {
            if (normalizedModelClass === 1) return "predicted";
            if (normalizedModelClass === 0) return "potential";
        }
    }
    return "unknown";
}

function partitionPredictionResults(featureCollection, threshold) {
    var source = featureCollection || {};
    var predicted = [];
    var potential = [];
    var unknown = [];
    (Array.isArray(source.features) ? source.features : []).forEach(function (feature) {
        var resultType = predictionResultType(feature, threshold);
        var copy = {
            type: feature.type || "Feature",
            geometry: feature.geometry,
            properties: {}
        };
        if (feature.id !== undefined) copy.id = feature.id;
        var properties = feature.properties || {};
        Object.keys(properties).forEach(function (key) { copy.properties[key] = properties[key]; });
        copy.properties.result_type = resultType;
        copy.properties.display_class = resultType;
        copy.properties.deeppipe_outcome = resultType;
        copy.properties.deeppipe_color = resultType === "predicted"
                ? "#16a34a"
                : (resultType === "potential" ? "#f59e0b" : "#64748b");
        if (resultType === "potential") potential.push(copy);
        else if (resultType === "predicted") predicted.push(copy);
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
        predictedCount: predicted.length,
        potentialCount: potential.length,
        unknownCount: unknown.length,
        total: predicted.length + potential.length + unknown.length
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
        var properties = feature.properties || {};
        Object.keys(properties).forEach(function (key) { copy.properties[key] = properties[key]; });
        copy.properties.job_id = String(jobId || "");
        copy.properties.analysis_mode = "live_api";
        copy.properties.review_status = copy.properties.review_status || "unreviewed";
        copy.properties.result_type = predictionResultType(copy, threshold);
        copy.properties.display_class = copy.properties.result_type;
        copy.properties.deeppipe_outcome = copy.properties.result_type;
        copy.properties.deeppipe_color = copy.properties.result_type === "predicted"
                ? "#16a34a"
                : (copy.properties.result_type === "potential" ? "#f59e0b" : "#64748b");
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
        potential: partitions.potentialCount > 0 ? partitions.potentialCount : null,
        unknown: partitions.unknownCount,
        selectedInlets: Number(selectedCount || 0),
        threshold: Number(threshold || 0)
    };
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
