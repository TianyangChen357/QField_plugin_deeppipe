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
            summary: { total: 0, predicted: 0, potential: 0 }
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
                class: 1,
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
    var names = Array.isArray(files) ? files.map(function (value) { return String(value); }) : [];
    var exact = names.find(function (name) { return name.toLowerCase() === "pipes.geojson"; });
    if (exact) return exact;
    var pipeGeoJson = names.find(function (name) {
        var lower = name.toLowerCase();
        return lower.endsWith(".geojson") && lower.indexOf("pipe") >= 0;
    });
    return pipeGeoJson || "";
}

function decorateLiveResult(featureCollection, jobId) {
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
    var features = featureCollection && Array.isArray(featureCollection.features)
            ? featureCollection.features : [];
    return {
        total: features.length,
        predicted: features.length,
        potential: null,
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
