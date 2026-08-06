import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import org.qfield
import org.qgis
import Theme
import "qrc:/qml" as QFieldItems
import "logic/DeepPipe.js" as DeepPipe

Item {
    id: plugin
    objectName: "deepPipeMobilePlugin"

    readonly property string pluginVersion: "0.5.14"
    readonly property string defaultApiBaseUrl: "https://lab.yyworkshop.com/predapi"
    readonly property string defaultPassApiBaseUrl: "https://lab.yyworkshop.com"

    property var mainWindow: iface.mainWindow()
    property var mapCanvas: iface.mapCanvas()
    property var positionSource: iface.positioning()
    // Register QField's point handler only while a DeepPipe map interaction is
    // active. Keeping it registered while idle can capture the first touch
    // after a fresh plugin install and force users to pan with two fingers.
    property var pointHandler: null
    property bool pointHandlerRegistered: false

    property bool hasProject: false
    property string projectName: "No project"
    property string projectPath: ""
    property string currentProjectKey: ""
    property string schemaVersion: ""
    property string setupState: "no_project"
    property string setupMessage: "Open a QField project to begin."
    readonly property bool projectReady: setupState === "ready"
    readonly property bool assessmentReady: hasProject
    property var layerNames: []
    property var layerIds: []
    property var inletLayer: null
    property string inletLayerId: ""
    property string inletLayerName: ""
    property var fieldNames: []
    property string nodeIdField: ""
    property bool mappingConfirmed: false
    property string mappingSource: ""

    property var selectedFids: []
    property var selectedPoints: []
    property string interactionMode: "idle"
    property string inletSelectionMode: "tap"
    property double lastMapTapMs: 0

    property var predictionConfig: DeepPipe.predictionDefaults()
    property string predictionStatus: "idle"
    property string predictionMessage: ""
    property var predictionSummary: null
    property var predictionResultLayer: null
    property string predictionExportGeoJson: ""
    property var predictionExportCrs: null
    property var predictionAttributeTable: ({ columns: [], rows: [] })
    property string predictionResultLayerName: ""
    property string predictionResultPath: ""
    property string lastPredictionExportPath: ""
    property string lastCompletedJobId: ""
    property bool hasPredictedResultGeometry: false
    property bool hasPotentialResultGeometry: false
    property bool focusedResultVisible: false
    property int mapLayerVisibilityRevision: 0
    property string activeMockJobId: ""
    property int mockPredictionStage: 0

    property string activeJobId: ""
    property string activeJobProjectKey: ""
    property string activeJobProjectName: ""
    property int activeJobSelectedCount: 0
    property double activeJobThreshold: 0.85
    property int pollFailureCount: 0

    property var activeRequest: null
    property var activeRequestCallback: null
    property int activeRequestSerial: 0
    property string apiConnectionStatus: "unknown"
    property string apiConnectionMessage: "Not checked"
    property string passApiConnectionStatus: "unknown"
    property string passApiConnectionMessage: "Not checked"

    property double assessmentLatitude: NaN
    property double assessmentLongitude: NaN
    property string assessmentLocationMethod: ""
    property string assessmentLocationLabel: "No location selected"
    property string assessmentStatus: "idle"
    property string assessmentMessage: "Choose a map or GNSS location."
    property var assessmentResult: null
    property double assessmentNominalDiameter: 16
    property int assessmentGauge: 16
    property string assessmentMaterialId: "rcp"
    property int assessmentMinimumYears: 0

    property var managedRasterLayers: []
    property var managedRasterLayerNames: []
    property string rasterStatus: "idle"
    property string rasterMessage: "No PyPASS raster has been added by the plugin."

    property bool selectionMutationInProgress: false
    property var geometryHighlighter: iface.findItemByObjectName("geometryHighlighter")
    readonly property bool predictionLayerLegendVisible: {
        var revision = mapLayerVisibilityRevision;
        var layer = predictionResultLayer;
        var layers = mapCanvas && mapCanvas.mapSettings
                ? (mapCanvas.mapSettings.layers || []) : [];
        if (!layer) return false;
        for (var index = 0; index < layers.length; index += 1) {
            if (layers[index] === layer ||
                    (layers[index] && String(layers[index].id) === String(layer.id))) return true;
        }
        return false;
    }

    // QField's app-wide QML API does not expose categorized renderer mutation.
    // A single transparent, persistent vector layer owns legend visibility,
    // selection, and attributes. These overlays supply the exact class colors
    // and follow that layer's legend state.
    QFieldItems.GeometryRenderer {
        id: predictedResultOverlay
        parent: mapCanvas ? mapCanvas : plugin
        anchors.fill: parent
        mapSettings: mapCanvas ? mapCanvas.mapSettings : null
        color: "#005035"
        lineWidth: 5.5
        visible: plugin.predictionLayerLegendVisible && plugin.hasPredictedResultGeometry
        z: 9000
    }

    QFieldItems.GeometryRenderer {
        id: potentialResultOverlay
        parent: mapCanvas ? mapCanvas : plugin
        anchors.fill: parent
        mapSettings: mapCanvas ? mapCanvas.mapSettings : null
        color: "#F4C430"
        lineWidth: 5.5
        visible: plugin.predictionLayerLegendVisible && plugin.hasPotentialResultGeometry
        z: 9001
    }

    QFieldItems.GeometryRenderer {
        id: focusedResultOverlay
        parent: mapCanvas ? mapCanvas : plugin
        anchors.fill: parent
        mapSettings: mapCanvas ? mapCanvas.mapSettings : null
        color: "#00A6D6"
        lineWidth: 10
        visible: plugin.focusedResultVisible
        z: 9002
    }

    Settings {
        id: appSettings
        category: "deeppipe-mobile"
        property bool useLiveApi: true
        property bool apiModeInitialized: false
        property string lastProjectName: ""
        property string projectMappingsJson: "{}"
        property string projectServiceSettingsJson: "{}"
        property string projectPredictionResultsJson: "{}"
        property string pendingJobsJson: "[]"
    }

    function configure() {
        loadProjectConfiguration(false);
        panelDrawer.open();
    }

    function ensurePointHandlerRegistered(showError) {
        if (pointHandlerRegistered && pointHandler) return true;
        var handler = pointHandler || iface.findItemByObjectName("pointHandler");
        if (!handler || typeof handler.registerHandler !== "function") {
            pointHandler = null;
            pointHandlerRegistered = false;
            iface.logMessage("DeepPipe Mobile could not find QField's map point handler.");
            if (showError) toast("Map selection is unavailable in this QField session. Reopen the project or restart QField, then try again.");
            return false;
        }
        var interactionHandler = function (point, type, interactionType) {
            if (interactionType !== "clicked") return false;
            if (plugin.interactionMode === "select_inlets") {
                return plugin.handleInletMapTap(point);
            }
            if (plugin.interactionMode === "assessment_location") {
                return plugin.handleAssessmentMapTap(point);
            }
            return false;
        };
        // The public QField plugin example uses the two-argument form. The v0.4
        // code passed a raw numeric priority, which is not portable across QField
        // builds and made the handler silently ineffective on some devices.
        try {
            if (typeof handler.deregisterHandler === "function") {
                handler.deregisterHandler("deeppipe_mobile_interactions");
            }
            handler.registerHandler("deeppipe_mobile_interactions", interactionHandler);
        } catch (error) {
            pointHandler = null;
            pointHandlerRegistered = false;
            iface.logMessage("DeepPipe Mobile could not register its map point handler: " + String(error));
            if (showError) toast("Map selection could not start. Restart QField, then try again.");
            return false;
        }
        pointHandler = handler;
        pointHandlerRegistered = true;
        return true;
    }

    function releasePointHandler() {
        if (pointHandlerRegistered && pointHandler &&
                typeof pointHandler.deregisterHandler === "function") {
            pointHandler.deregisterHandler("deeppipe_mobile_interactions");
        }
        pointHandlerRegistered = false;
    }

    function toast(message) {
        if (mainWindow && message) {
            mainWindow.displayToast(String(message));
        }
    }

    function finishApiRequest(token, ok, payload, status, message) {
        if (token !== activeRequestSerial) return;
        var callback = activeRequestCallback;
        activeRequest = null;
        activeRequestCallback = null;
        if (callback) callback(Boolean(ok), payload, Number(status || 0), String(message || ""));
    }

    function abandonActiveRequest() {
        var request = activeRequest;
        activeRequestSerial += 1;
        activeRequest = null;
        activeRequestCallback = null;
        if (request && typeof request.abort === "function") request.abort();
    }

    function sendApiRequestTo(baseUrl, method, path, body, timeoutMs, callback) {
        if (activeRequest) {
            if (callback) callback(false, null, 0, "Another DeepPipe request is still in progress.");
            return false;
        }
        var url = DeepPipe.apiUrl(baseUrl, path);
        if (!url) {
            if (callback) callback(false, null, 0, "The configured DeepPipe service endpoint is invalid.");
            return false;
        }

        var request = iface.createHttpRequest();
        if (!request) {
            if (callback) callback(false, null, 0, "This QField version cannot create an HTTP request.");
            return false;
        }

        activeRequestSerial += 1;
        var token = activeRequestSerial;
        activeRequest = request;
        activeRequestCallback = callback;
        request.timeout = Number(timeoutMs || 30000);

        request.onload = function () {
            var payload = DeepPipe.tryParseJson(request.responseText);
            var status = Number(request.status || 0);
            var ok = status >= 200 && status < 300;
            finishApiRequest(
                        token,
                        ok,
                        payload,
                        status,
                        ok ? "" : DeepPipe.apiErrorMessage(payload, status, request.responseText));
        };
        request.onerror = function (code, message) {
            finishApiRequest(token, false, null, 0, String(message || "Network request failed."));
        };
        request.ontimeout = function () {
            finishApiRequest(token, false, null, 0, "The DeepPipe API request timed out.");
        };
        request.onaborted = function () {
            finishApiRequest(token, false, null, 0, "The DeepPipe API request was stopped.");
        };

        request.open(String(method || "GET"), url);
        request.setRequestHeader("Accept", "application/json");
        if (body !== undefined && body !== null) {
            request.setRequestHeader("Content-Type", "application/json");
            request.send(JSON.stringify(body));
        } else {
            request.send();
        }
        return true;
    }

    function sendApiRequest(method, path, body, timeoutMs, callback) {
        return sendApiRequestTo(defaultApiBaseUrl, method, path, body, timeoutMs, callback);
    }

    function saveCurrentProjectServiceSettings() {
        if (!hasProject || !currentProjectKey) return;
        appSettings.projectServiceSettingsJson = DeepPipe.updateProjectServiceSettings(
                    appSettings.projectServiceSettingsJson,
                    projectPath,
                    projectName,
                    {
                        prediction_config: predictionConfig
                    });
    }

    function savedPredictionResultState() {
        if (!hasProject || !currentProjectKey) return null;
        return DeepPipe.predictionResultState(
                    appSettings.projectPredictionResultsJson,
                    projectPath,
                    projectName);
    }

    function savePredictionResultState(path, jobId, threshold, selectedCount) {
        if (!hasProject || !currentProjectKey || !path) return;
        appSettings.projectPredictionResultsJson = DeepPipe.updatePredictionResultState(
                    appSettings.projectPredictionResultsJson,
                    projectPath,
                    projectName,
                    {
                        path: path,
                        layer_name: "DeepPipe Prediction Results",
                        job_id: jobId,
                        threshold: threshold,
                        selected_count: selectedCount,
                        saved_at: new Date().toISOString()
                    });
    }

    function clearPredictionResultState() {
        if (!hasProject || !currentProjectKey) return;
        appSettings.projectPredictionResultsJson = DeepPipe.updatePredictionResultState(
                    appSettings.projectPredictionResultsJson,
                    projectPath,
                    projectName,
                    null);
    }

    function testApiConnections() {
        if (activeRequest) {
            toast("Another DeepPipe request is already in progress.");
            return;
        }
        apiConnectionStatus = "checking";
        apiConnectionMessage = "Checking Prediction API…";
        passApiConnectionStatus = "checking";
        passApiConnectionMessage = "Waiting for Prediction API check…";
        sendApiRequest("GET", "/health", null, 20000, function (ok, payload, status, message) {
            if (ok && payload && String(payload.status).toLowerCase() === "ok") {
                apiConnectionStatus = "ok";
                apiConnectionMessage = "Online" + (payload.device ? " · " + payload.device : "");
            } else {
                apiConnectionStatus = "failed";
                apiConnectionMessage = message || "Prediction API health check failed";
            }

            passApiConnectionMessage = "Checking PyPASS API…";
            sendApiRequestTo(defaultPassApiBaseUrl, "GET", "/api/pypass/variables", null, 20000,
                             function (passOk, passPayload, passStatus, passMessage) {
                var variables = passOk && Array.isArray(passPayload)
                        ? passPayload
                        : (passOk && passPayload && Array.isArray(passPayload.variables)
                           ? passPayload.variables : []);
                if (passOk && variables.length > 0) {
                    passApiConnectionStatus = "ok";
                    passApiConnectionMessage = "Online";
                } else {
                    passApiConnectionStatus = "failed";
                    passApiConnectionMessage = passMessage || "PyPASS API health check failed";
                }
                toast(apiConnectionStatus === "ok" && passApiConnectionStatus === "ok"
                      ? "Prediction and PyPASS APIs are online."
                      : "API status check finished; review the status panel.");
            });
        });
    }

    function setPredictionConfig(settings) {
        if (activeJobId || activeRequest) {
            toast("Wait for the current Prediction request before changing prediction settings.");
            return;
        }
        predictionConfig = DeepPipe.normalizePredictionConfig(settings);
        saveCurrentProjectServiceSettings();
    }

    function persistActiveJob() {
        if (!activeJobId) {
            appSettings.pendingJobsJson = "[]";
            return;
        }
        appSettings.pendingJobsJson = JSON.stringify([{
            job_id: activeJobId,
            project_key: activeJobProjectKey,
            project_name: activeJobProjectName,
            selected_count: activeJobSelectedCount,
            threshold: activeJobThreshold,
            saved_at: new Date().toISOString()
        }]);
    }

    function clearActiveJob() {
        jobPollTimer.stop();
        activeJobId = "";
        activeJobProjectKey = "";
        activeJobProjectName = "";
        activeJobSelectedCount = 0;
        activeJobThreshold = predictionConfig.classification_threshold;
        pollFailureCount = 0;
        appSettings.pendingJobsJson = "[]";
    }

    function restorePendingJob() {
        if (!hasProject) return;
        if (!activeJobId) {
            var stored = DeepPipe.tryParseJson(appSettings.pendingJobsJson);
            if (!Array.isArray(stored) || stored.length === 0 || !stored[0].job_id) return;
            var pending = stored[0];
            activeJobId = String(pending.job_id);
            activeJobProjectKey = String(pending.project_key || "");
            activeJobProjectName = String(pending.project_name || "");
            activeJobSelectedCount = Number(pending.selected_count || 0);
            activeJobThreshold = Number(pending.threshold || predictionConfig.classification_threshold);
        }
        predictionStatus = "queued";
        if ((activeJobProjectKey && activeJobProjectKey !== currentProjectKey) ||
                (!activeJobProjectKey && activeJobProjectName && activeJobProjectName !== projectName)) {
            predictionMessage = "Saved job " + activeJobId + " belongs to project '" + activeJobProjectName + "'. Reopen that project to resume.";
            return;
        }
        predictionMessage = "Resuming prediction job " + activeJobId + "…";
        jobPollTimer.interval = 300;
        jobPollTimer.restart();
    }

    function layerById(layerId) {
        if (!qgisProject || !layerId) return null;
        var layers = ProjectUtils.mapLayers(qgisProject);
        return layers[String(layerId)] || null;
    }

    function uniqueLayerIdByName(name) {
        var match = "";
        var count = 0;
        var layers = qgisProject ? ProjectUtils.mapLayers(qgisProject) : {};
        for (var layerId in layers) {
            if (String(layers[layerId].name) === String(name) && layerIds.indexOf(String(layerId)) >= 0) {
                match = String(layerId);
                count += 1;
            }
        }
        return count === 1 ? match : "";
    }

    function refreshLayerOptions() {
        var options = [];
        var duplicateCounts = {};
        var layers = qgisProject ? ProjectUtils.mapLayers(qgisProject) : {};
        for (var layerId in layers) {
            var layer = layers[layerId];
            if (layer && typeof layer.selectedFeatures === "function" &&
                    typeof layer.geometryType === "function" &&
                    layer.geometryType() === Qgis.GeometryType.Point) {
                var layerName = String(layer.name);
                duplicateCounts[layerName] = Number(duplicateCounts[layerName] || 0) + 1;
                options.push({ id: String(layerId), name: layerName });
            }
        }
        options.sort(function (left, right) {
            return left.name.toLowerCase().localeCompare(right.name.toLowerCase());
        });
        var labels = [];
        var ids = [];
        options.forEach(function (option) {
            labels.push(duplicateCounts[option.name] > 1
                        ? option.name + " · " + option.id.slice(0, 8)
                        : option.name);
            ids.push(option.id);
        });
        layerNames = labels;
        layerIds = ids;
    }

    function refreshFieldNames() {
        var names = [];
        try {
            var fields = inletLayer ? inletLayer.fields : null;
            var availableNames = fields ? fields.names : [];
            if (typeof availableNames === "function") availableNames = availableNames();
            names = DeepPipe.stringList(availableNames);
        } catch (error) {
            names = [];
        }
        names.sort(function (left, right) { return left.toLowerCase().localeCompare(right.toLowerCase()); });
        fieldNames = names;
    }

    function suggestedLayerId() {
        if (layerIds.length === 1) return String(layerIds[0]);
        var preferredNames = ["inlets", "inlet", "catch basins", "catchbasins", "storm drains", "stormwater inlets", "nodes"];
        var layers = qgisProject ? ProjectUtils.mapLayers(qgisProject) : {};
        for (var preferredIndex = 0; preferredIndex < preferredNames.length; preferredIndex += 1) {
            for (var layerIndex = 0; layerIndex < layerIds.length; layerIndex += 1) {
                var candidateId = String(layerIds[layerIndex]);
                if (layers[candidateId] && String(layers[candidateId].name).toLowerCase() === preferredNames[preferredIndex]) {
                    return candidateId;
                }
            }
        }
        return "";
    }

    function refreshSetupState() {
        if (!hasProject) {
            setupState = "no_project";
            setupMessage = "Open a QField project to begin.";
        } else if (layerIds.length === 0) {
            setupState = "no_point_layers";
            setupMessage = "This project has no point layer. Add an inlet point layer first.";
        } else if (!inletLayer || !inletLayerId) {
            setupState = "needs_layer";
            setupMessage = "Choose which point layer contains the stormwater inlets.";
        } else if (!nodeIdField) {
            setupState = "needs_field";
            setupMessage = "Choose a stable unique ID field. A UUID text field is recommended for multi-user work.";
        } else if (fieldNames.indexOf(nodeIdField) < 0) {
            setupState = "invalid_field";
            setupMessage = "The ID field '" + nodeIdField + "' is not present in " + inletLayerName + ".";
        } else if (!mappingConfirmed) {
            setupState = "needs_confirmation";
            setupMessage = "Review the inlet layer and ID field, then confirm this project setup.";
        } else {
            setupState = "ready";
            setupMessage = "Ready to select inlets from " + inletLayerName + " using " + nodeIdField + ".";
        }
    }

    function loadProjectConfiguration(resetWorkflow) {
        var previousProjectKey = currentProjectKey;
        var previousLayerId = inletLayerId;
        var rawProjectTitle = qgisProject ? String(ProjectUtils.title(qgisProject) || "") : "";
        var nextProjectPath = qgisProject ? String(qgisProject.fileName || "") : "";

        refreshLayerOptions();
        hasProject = Boolean(qgisProject && (nextProjectPath || rawProjectTitle || layerIds.length > 0));
        projectName = hasProject ? (rawProjectTitle || "Untitled QField project") : "No project";
        projectPath = hasProject ? nextProjectPath : "";
        currentProjectKey = hasProject ? DeepPipe.projectKey(projectPath, projectName) : "";
        schemaVersion = hasProject ? String(iface.readProjectEntry("DeepPipe", "schema_version", "")) : "";

        var configuredLayerName = hasProject ? String(iface.readProjectEntry("DeepPipe", "inlet_layer", "")) : "";
        var configuredNodeField = hasProject ? String(iface.readProjectEntry("DeepPipe", "node_id_field", "")) : "";
        var configuredApiMode = hasProject ? String(iface.readProjectEntry("DeepPipe", "api_mode", "")).toLowerCase() : "";
        var savedMapping = hasProject
                ? DeepPipe.projectMapping(appSettings.projectMappingsJson, projectPath, projectName)
                : null;
        var savedServiceSettings = hasProject
                ? DeepPipe.projectServiceSettings(appSettings.projectServiceSettingsJson, projectPath, projectName)
                : null;

        var nextLayerId = "";
        var nextNodeField = "";
        mappingSource = "";
        mappingConfirmed = false;

        if (savedMapping) {
            nextLayerId = layerById(savedMapping.layer_id) ? String(savedMapping.layer_id) : uniqueLayerIdByName(savedMapping.layer_name);
            nextNodeField = String(savedMapping.node_id_field || "");
            mappingSource = "local";
            mappingConfirmed = Boolean(nextLayerId);
        }
        if (!nextLayerId && configuredLayerName) {
            nextLayerId = uniqueLayerIdByName(configuredLayerName);
            nextNodeField = configuredNodeField;
            mappingSource = "project";
            mappingConfirmed = Boolean(nextLayerId);
        }
        if (!nextLayerId) {
            nextLayerId = suggestedLayerId();
            nextNodeField = configuredNodeField;
            mappingSource = nextLayerId ? "suggestion" : "";
            mappingConfirmed = false;
        }

        inletLayerId = nextLayerId;
        inletLayer = layerById(nextLayerId);
        inletLayerName = inletLayer ? String(inletLayer.name) : "";
        refreshFieldNames();
        nodeIdField = DeepPipe.suggestedNodeIdField(fieldNames, nextNodeField);
        if (!nodeIdField || fieldNames.indexOf(nodeIdField) < 0) mappingConfirmed = false;
        refreshSetupState();

        apiConnectionStatus = "unknown";
        apiConnectionMessage = "Not checked";
        passApiConnectionStatus = "unknown";
        passApiConnectionMessage = "Not checked";
        predictionConfig = DeepPipe.normalizePredictionConfig(
                    savedServiceSettings && savedServiceSettings.prediction_config
                    ? savedServiceSettings.prediction_config
                    : DeepPipe.predictionDefaults());
        if (!appSettings.apiModeInitialized) {
            if (configuredApiMode === "live") appSettings.useLiveApi = true;
            if (configuredApiMode === "mock") appSettings.useLiveApi = false;
            appSettings.apiModeInitialized = true;
        }
        appSettings.lastProjectName = projectName;

        var shouldReset = Boolean(resetWorkflow) ||
                previousProjectKey !== currentProjectKey ||
                previousLayerId !== inletLayerId;
        if (shouldReset) {
            releasePointHandler();
            selectedFids = [];
            selectedPoints = [];
            detachPredictionLayer();
            lastCompletedJobId = "";
            removeManagedRasterLayers();
            assessmentLatitude = NaN;
            assessmentLongitude = NaN;
            assessmentLocationMethod = "";
            assessmentLocationLabel = "No location selected";
            assessmentResult = null;
            assessmentStatus = "idle";
            assessmentMessage = "Choose a map or GNSS location.";
            restorePersistedPredictionResult();
            restorePendingJob();
        }
    }

    function chooseInletLayer(layerId) {
        if (activeJobId || activeRequest) {
            toast("Wait for or cancel the active Prediction job before changing project setup.");
            return;
        }
        var nextLayer = layerById(layerId);
        if (!nextLayer) {
            toast("The selected point layer could not be loaded.");
            return;
        }
        selectedFids = [];
        selectedPoints = [];
        removePredictionLayer();
        inletLayerId = String(layerId);
        inletLayerName = String(nextLayer.name);
        inletLayer = nextLayer;
        refreshFieldNames();
        nodeIdField = DeepPipe.suggestedNodeIdField(fieldNames, nodeIdField);
        mappingConfirmed = false;
        mappingSource = "user";
        predictionStatus = "idle";
        predictionMessage = "";
        predictionSummary = null;
        refreshSetupState();
    }

    function chooseNodeIdField(fieldName) {
        if (activeJobId || activeRequest) {
            toast("Wait for or cancel the active Prediction job before changing project setup.");
            return;
        }
        selectedFids = [];
        selectedPoints = [];
        removePredictionLayer();
        nodeIdField = String(fieldName || "").trim();
        mappingConfirmed = false;
        mappingSource = "user";
        predictionStatus = "idle";
        predictionMessage = "";
        predictionSummary = null;
        refreshSetupState();
    }

    function confirmProjectMapping() {
        refreshFieldNames();
        if (!hasProject || !inletLayer || !inletLayerId || !nodeIdField || fieldNames.indexOf(nodeIdField) < 0) {
            mappingConfirmed = false;
            refreshSetupState();
            toast(setupMessage);
            return;
        }
        mappingConfirmed = true;
        mappingSource = "local";
        appSettings.projectMappingsJson = DeepPipe.updateProjectMapping(
                    appSettings.projectMappingsJson,
                    projectPath,
                    projectName,
                    {
                        layer_id: inletLayerId,
                        layer_name: inletLayerName,
                        node_id_field: nodeIdField,
                        confirmed_at: new Date().toISOString()
                    });
        refreshSetupState();
        toast("DeepPipe setup saved for this project on this device.");
    }

    function recordFromFeature(feature) {
        if (!feature || !inletLayer) return null;
        if (typeof inletLayer.geometryType !== "function" ||
                inletLayer.geometryType() !== Qgis.GeometryType.Point) return null;
        var geometry = feature.geometry;
        if (!geometry) return null;
        var point = GeometryUtils.centroid(geometry);
        var wgs84Point = GeometryUtils.reprojectPointToWgs84(point, inletLayer.crs);
        return {
            fid: Number(feature.id),
            nodeId: feature.attribute(nodeIdField),
            x: Number(point.x),
            y: Number(point.y),
            longitude: Number(wgs84Point.x),
            latitude: Number(wgs84Point.y)
        };
    }

    function syncFromNativeSelection() {
        if (!inletLayer || typeof inletLayer.selectedFeatures !== "function") return;
        var features = inletLayer.selectedFeatures();
        var nextPoints = [];
        var nextFids = [];
        for (var index = 0; index < features.length; index += 1) {
            var record = recordFromFeature(features[index]);
            if (record && Number.isFinite(record.fid)) {
                nextPoints.push(record);
                nextFids.push(record.fid);
            }
        }
        selectedPoints = nextPoints;
        selectedFids = nextFids;
    }

    function updateNativeSelection() {
        if (!inletLayer) return;
        selectionMutationInProgress = true;
        LayerUtils.selectFeaturesInLayer(inletLayer, selectedFids);
        selectionMutationInProgress = false;
    }

    function toggleFeature(feature) {
        var record = recordFromFeature(feature);
        if (!record || !Number.isFinite(record.fid)) {
            toast("That feature does not have usable point geometry.");
            return;
        }

        var nextFids = selectedFids.slice();
        var nextPoints = selectedPoints.slice();
        var existingIndex = nextFids.indexOf(record.fid);
        if (existingIndex >= 0) {
            nextFids.splice(existingIndex, 1);
            nextPoints.splice(existingIndex, 1);
        } else {
            nextFids.push(record.fid);
            nextPoints.push(record);
        }
        selectedFids = nextFids;
        selectedPoints = nextPoints;
        updateNativeSelection();
    }

    function clearSelectedInlets() {
        selectedFids = [];
        selectedPoints = [];
        if (inletLayer) updateNativeSelection();
        predictionSummary = null;
        if (predictionStatus !== "running") {
            predictionStatus = "idle";
            predictionMessage = "";
        }
    }

    function startInletSelection() {
        if (!projectReady || !inletLayer) {
            toast(setupMessage);
            return;
        }
        // Keep the public QField point handler as a compatibility path, but do
        // not block selection when a build exposes the map canvas without it.
        // The transparent map overlay below handles both tap and box gestures.
        ensurePointHandlerRegistered(false);
        syncFromNativeSelection();
        interactionMode = "select_inlets";
        inletSelectionMode = "tap";
        panelDrawer.close();
        toast("Tap points, drag a box, or select all visible inlets.");
    }

    function finishMapInteraction() {
        interactionMode = "idle";
        releasePointHandler();
        panelDrawer.open();
    }

    function cancelMapInteraction() {
        interactionMode = "idle";
        releasePointHandler();
        panelDrawer.open();
    }

    function setInletSelectionMode(mode) {
        var normalized = String(mode || "tap") === "box" ? "box" : "tap";
        inletSelectionMode = normalized;
        toast(normalized === "box"
              ? "Drag a rectangle around the inlets to add."
              : "Tap an inlet to add or remove it.");
    }

    function mapRectangleFromScreenBounds(left, top, right, bottom) {
        if (!mapCanvas) return null;
        var corners = [
            mapCanvas.mapSettings.screenToCoordinate(Qt.point(left, top)),
            mapCanvas.mapSettings.screenToCoordinate(Qt.point(right, top)),
            mapCanvas.mapSettings.screenToCoordinate(Qt.point(right, bottom)),
            mapCanvas.mapSettings.screenToCoordinate(Qt.point(left, bottom))
        ];
        var minimumX = Number.POSITIVE_INFINITY;
        var minimumY = Number.POSITIVE_INFINITY;
        var maximumX = Number.NEGATIVE_INFINITY;
        var maximumY = Number.NEGATIVE_INFINITY;
        corners.forEach(function (corner) {
            minimumX = Math.min(minimumX, Number(corner.x));
            minimumY = Math.min(minimumY, Number(corner.y));
            maximumX = Math.max(maximumX, Number(corner.x));
            maximumY = Math.max(maximumY, Number(corner.y));
        });
        // createRectangleFromPoints() requires QgsPoint values. Qt.point()
        // creates QPointF values, which some QField builds cannot convert and
        // therefore yields an empty feature query for Tap, Box, and Visible.
        return GeometryUtils.createRectangleFromPoints(
                    GeometryUtils.point(minimumX, minimumY),
                    GeometryUtils.point(maximumX, maximumY));
    }

    function recordsInScreenRectangle(startPoint, endPoint) {
        var records = [];
        if (!inletLayer || !mapCanvas) return records;
        var left = Math.min(Number(startPoint.x), Number(endPoint.x));
        var right = Math.max(Number(startPoint.x), Number(endPoint.x));
        var top = Math.min(Number(startPoint.y), Number(endPoint.y));
        var bottom = Math.max(Number(startPoint.y), Number(endPoint.y));
        var rectangle = mapRectangleFromScreenBounds(left, top, right, bottom);
        var layerRectangle = GeometryUtils.reprojectRectangle(
                    rectangle,
                    mapCanvas.mapSettings.destinationCrs,
                    inletLayer.crs);
        var iterator = LayerUtils.createFeatureIteratorFromRectangle(inletLayer, layerRectangle);
        while (iterator && iterator.hasNext()) {
            var record = recordFromFeature(iterator.next());
            if (record && Number.isFinite(record.fid)) records.push(record);
        }
        if (iterator && typeof iterator.close === "function") iterator.close();
        return records;
    }

    function addInletsInScreenRectangle(startPoint, endPoint, actionLabel) {
        if (!projectReady || !inletLayer) {
            toast(setupMessage);
            return 0;
        }
        var incoming = recordsInScreenRectangle(startPoint, endPoint);
        var merged = DeepPipe.mergePointRecords(selectedPoints, incoming);
        selectedPoints = merged.records;
        selectedFids = merged.records.map(function (record) { return Number(record.fid); });
        updateNativeSelection();
        predictionSummary = null;
        var label = String(actionLabel || "Box selection");
        if (incoming.length === 0) {
            toast(label + " found no inlets.");
        } else if (merged.added === 0) {
            toast("All " + incoming.length + " inlets in that area were already selected.");
        } else {
            toast("Added " + merged.added + " inlet" + (merged.added === 1 ? "" : "s") + ".");
        }
        return merged.added;
    }

    function selectVisibleInlets() {
        if (!mapCanvas) return;
        addInletsInScreenRectangle(
                    Qt.point(0, 0),
                    Qt.point(Number(mapCanvas.width), Number(mapCanvas.height)),
                    "Visible-area selection");
    }

    function handleInletMapTap(screenPoint) {
        if (!inletLayer || !mapCanvas) return true;
        if (inletSelectionMode !== "tap") return true;
        var now = Date.now();
        if (now - lastMapTapMs < 220) return true;
        lastMapTapMs = now;

        var tolerance = 16;
        var rectangle = mapRectangleFromScreenBounds(
                    screenPoint.x - tolerance,
                    screenPoint.y - tolerance,
                    screenPoint.x + tolerance,
                    screenPoint.y + tolerance);
        var layerRectangle = GeometryUtils.reprojectRectangle(
                    rectangle,
                    mapCanvas.mapSettings.destinationCrs,
                    inletLayer.crs);
        var iterator = LayerUtils.createFeatureIteratorFromRectangle(inletLayer, layerRectangle);
        var tapLayerPoint = GeometryUtils.reprojectPoint(
                    mapCanvas.mapSettings.screenToCoordinate(Qt.point(screenPoint.x, screenPoint.y)),
                    mapCanvas.mapSettings.destinationCrs,
                    inletLayer.crs);
        var feature = null;
        var shortestDistance = Number.POSITIVE_INFINITY;
        while (iterator && iterator.hasNext()) {
            var candidate = iterator.next();
            if (!candidate || !candidate.geometry) continue;
            var candidatePoint = GeometryUtils.centroid(candidate.geometry);
            var distance = GeometryUtils.distanceBetweenPoints(tapLayerPoint, candidatePoint);
            if (distance < shortestDistance) {
                shortestDistance = distance;
                feature = candidate;
            }
        }
        if (iterator && typeof iterator.close === "function") {
            iterator.close();
        }

        if (!feature) {
            toast("No inlet found at that location. Zoom in and try again.");
            return true;
        }
        toggleFeature(feature);
        return true;
    }

    function startAssessmentLocationSelection() {
        if (!assessmentReady) {
            toast("Open a QField project first.");
            return;
        }
        ensurePointHandlerRegistered(false);
        interactionMode = "assessment_location";
        panelDrawer.close();
        toast("Tap the map at the assessment location.");
    }

    function setAssessmentLocation(latitude, longitude, method) {
        assessmentLatitude = Number(latitude);
        assessmentLongitude = Number(longitude);
        assessmentLocationMethod = String(method || "map point");
        assessmentLocationLabel = assessmentLocationMethod + ": " +
                assessmentLatitude.toFixed(6) + ", " + assessmentLongitude.toFixed(6);
        assessmentResult = null;
        assessmentStatus = "ready";
        assessmentMessage = "Location ready for live PyPASS assessment.";
    }

    function handleAssessmentMapTap(screenPoint) {
        var now = Date.now();
        if (now - lastMapTapMs < 220) return true;
        lastMapTapMs = now;
        var projectPoint = mapCanvas.mapSettings.screenToCoordinate(Qt.point(screenPoint.x, screenPoint.y));
        var wgs84 = GeometryUtils.reprojectPointToWgs84(projectPoint, mapCanvas.mapSettings.destinationCrs);
        setAssessmentLocation(Number(wgs84.y), Number(wgs84.x), "Map point");
        interactionMode = "idle";
        releasePointHandler();
        panelDrawer.open();
        return true;
    }

    function useCurrentGnssLocation() {
        if (!positionSource || !positionSource.active) {
            toast("GNSS positioning is not active.");
            return;
        }
        var information = positionSource.positionInformation;
        if (!information.latitudeValid || !information.longitudeValid) {
            toast("A valid GNSS fix is not available yet.");
            return;
        }
        setAssessmentLocation(information.latitude, information.longitude, "GNSS");
    }

    function runLiveAssessment() {
        if (activeRequest) {
            assessmentStatus = "failed";
            assessmentMessage = "Wait for the current DeepPipe network request to finish.";
            toast(assessmentMessage);
            return;
        }
        if (!Number.isFinite(assessmentLatitude) || assessmentLatitude < -90 || assessmentLatitude > 90 ||
                !Number.isFinite(assessmentLongitude) || assessmentLongitude < -180 || assessmentLongitude > 180) {
            assessmentStatus = "failed";
            assessmentMessage = "Choose a valid map or GNSS location before assessment.";
            toast(assessmentMessage);
            return;
        }
        if (!Number.isFinite(assessmentNominalDiameter) || assessmentNominalDiameter <= 0) {
            assessmentStatus = "failed";
            assessmentMessage = "The service-life reference size is invalid.";
            toast(assessmentMessage);
            return;
        }
        if (!DeepPipe.normalizeApiBaseUrl(defaultPassApiBaseUrl)) {
            assessmentStatus = "failed";
            assessmentMessage = "The built-in PyPASS service endpoint is invalid.";
            toast(assessmentMessage);
            return;
        }
        assessmentStatus = "running";
        assessmentMessage = "Querying live soil properties and service-life estimates…";
        assessmentResult = null;
        var body = {
            latitude: Number(assessmentLatitude),
            longitude: Number(assessmentLongitude),
            nominal_diameter_cast_iron: Number(assessmentNominalDiameter),
            location_id: "qfield-" + DeepPipe.safeFilePart(projectName, "project")
        };
        sendApiRequestTo(defaultPassApiBaseUrl, "POST", "/api/pypass/service-life", body, 60000,
                         function (ok, payload, status, message) {
            if (!ok) {
                assessmentStatus = "failed";
                assessmentMessage = message || "PyPASS assessment failed.";
                toast(assessmentMessage);
                return;
            }
            var result = DeepPipe.normalizeLiveAssessment(payload, assessmentGauge);
            if (!result.ok) {
                assessmentStatus = "failed";
                assessmentMessage = "PyPASS returned an incomplete location response.";
                toast(assessmentMessage);
                return;
            }
            assessmentResult = result;
            assessmentStatus = "succeeded";
            assessmentMessage = result.warnings.length > 0
                    ? "Assessment completed with " + result.warnings.length + " data-coverage warning" + (result.warnings.length === 1 ? "." : "s.")
                    : "Live PyPASS assessment completed.";
            toast(assessmentMessage);
        });
    }

    function setAssessmentInputs(nominalDiameter, gauge, materialId, minimumYears) {
        var diameter = Number(nominalDiameter);
        if (Number.isFinite(diameter) && diameter > 0) assessmentNominalDiameter = diameter;
        var material = DeepPipe.passMaterialById(materialId);
        var allowedGauges = DeepPipe.passGaugeOptions(material.id);
        var nextGauge = Math.round(Number(gauge));
        assessmentMaterialId = material.id;
        if (allowedGauges.length === 0) {
            assessmentGauge = 0;
        } else if (allowedGauges.indexOf(nextGauge) >= 0) {
            assessmentGauge = nextGauge;
        } else {
            assessmentGauge = Number(material.default_gauge || allowedGauges[0]);
        }
        assessmentMinimumYears = Math.max(0, Math.round(Number(minimumYears) || 0));
        assessmentResult = null;
        if (assessmentStatus === "succeeded") assessmentStatus = "ready";
    }

    function addManagedRasterLayer(uri, layerName, provider, opacity) {
        if (!qgisProject || !uri) {
            rasterStatus = "failed";
            rasterMessage = "Open a project and provide a valid raster source.";
            toast(rasterMessage);
            return false;
        }
        var names = managedRasterLayerNames.slice();
        var layers = managedRasterLayers.slice();
        var existingIndex = names.indexOf(String(layerName));
        if (existingIndex >= 0) {
            ProjectUtils.removeMapLayer(qgisProject, layers[existingIndex]);
            names.splice(existingIndex, 1);
            layers.splice(existingIndex, 1);
            managedRasterLayers = layers.slice();
            managedRasterLayerNames = names.slice();
        }
        var layer = LayerUtils.loadRasterLayer(String(uri), String(layerName), String(provider || "gdal"));
        if (!layer || !layer.isValid || !ProjectUtils.addMapLayer(qgisProject, layer)) {
            rasterStatus = "failed";
            rasterMessage = "QField could not open '" + layerName + "'. Check the URL, TLS access, and raster format.";
            toast(rasterMessage);
            return false;
        }
        layer.opacity = Math.max(0.15, Math.min(1.0, Number(opacity || 0.78)));
        layers.push(layer);
        names.push(String(layerName));
        managedRasterLayers = layers;
        managedRasterLayerNames = names;
        rasterStatus = "succeeded";
        rasterMessage = "Added " + layerName + " to the current map.";
        toast(rasterMessage);
        return true;
    }

    function addXyzRasterFromTemplate(template, layerName) {
        var fullUrl = DeepPipe.resolveCatalogUrl(defaultPassApiBaseUrl, template);
        var uri = DeepPipe.xyzRasterUri(fullUrl, 7, 19);
        return addManagedRasterLayer(uri, layerName, "wms", 0.78);
    }

    function addPassVariableRaster(variableId, fallbackName) {
        if (activeRequest) {
            toast("Wait for the current DeepPipe request before adding a raster.");
            return;
        }
        rasterStatus = "loading";
        rasterMessage = "Reading the live PyPASS raster catalog…";
        sendApiRequestTo(defaultPassApiBaseUrl, "GET", "/api/pypass/variables", null, 30000,
                         function (ok, payload, status, message) {
            var variables = ok && Array.isArray(payload)
                    ? payload
                    : (ok && payload && Array.isArray(payload.variables) ? payload.variables : []);
            var variable = variables.find(function (item) { return String(item && item.id) === String(variableId); });
            var tilePath = variable && variable.tile_url
                    ? String(variable.tile_url)
                    : DeepPipe.passVariableTilePath(variableId);
            var layerName = "PyPASS " + String(variable && variable.name || fallbackName || variableId);
            if (!tilePath || !addXyzRasterFromTemplate(tilePath, layerName)) {
                rasterStatus = "failed";
                rasterMessage = message || "The PyPASS raster catalog did not provide a usable tile URL.";
            }
        });
    }

    function addPassServiceLifeRaster() {
        if (activeRequest) {
            toast("Wait for the current DeepPipe request before adding a raster.");
            return;
        }
        var material = DeepPipe.passMaterialById(assessmentMaterialId);
        rasterStatus = "loading";
        rasterMessage = "Reading live PyPASS service-life layer options…";
        sendApiRequestTo(defaultPassApiBaseUrl, "GET", "/api/pypass/service-life-layer/options", null, 30000,
                         function (ok, payload, status, message) {
            var template = ok && payload && payload.tile_url
                    ? String(payload.tile_url)
                    : "/api/pypass/service-life-tiles/{material_id}/{z}/{x}/{y}.png";
            template = template.replace("{material_id}", encodeURIComponent(material.id));
            var gaugeSelection = DeepPipe.passRasterGauge(
                        material.id,
                        assessmentGauge,
                        ok && payload && Array.isArray(payload.materials) ? payload.materials : []);
            var query = "min_years=" + Math.max(0, assessmentMinimumYears);
            if (gaugeSelection.requiresGauge) query += "&gauge=" + gaugeSelection.gauge;
            template = DeepPipe.appendUrlQuery(template, query);
            var layerName = "PyPASS " + material.name + " ≥ " + assessmentMinimumYears + " yr" +
                    (gaugeSelection.requiresGauge ? " · gauge " + gaugeSelection.gauge : "");
            if (!addXyzRasterFromTemplate(template, layerName)) {
                rasterStatus = "failed";
                rasterMessage = message || "The service-life raster could not be added.";
                return;
            }
            if (gaugeSelection.adjusted) {
                rasterMessage = "Added " + layerName + ". Gauge " + gaugeSelection.requestedGauge +
                        " is unavailable for " + material.name + "; the catalog default gauge " +
                        gaugeSelection.gauge + " was used.";
                toast(rasterMessage);
            }
        });
    }

    function removeManagedRasterLayers() {
        if (qgisProject) {
            (Array.isArray(managedRasterLayers) ? managedRasterLayers : []).forEach(function (layer) {
                if (layer) ProjectUtils.removeMapLayer(qgisProject, layer);
            });
        }
        managedRasterLayers = [];
        managedRasterLayerNames = [];
        rasterStatus = "idle";
        rasterMessage = "No PyPASS raster has been added by the plugin.";
    }

    function isManagedPredictionLayer(layer) {
        if (!layer) return false;
        var marked = false;
        if (typeof layer.customProperty === "function") {
            marked = Boolean(layer.customProperty("deeppipe/managed_prediction_result", false));
        }
        var name = String(layer.name || "");
        return marked || name === "DeepPipe Prediction Results" ||
                name.indexOf("DeepPipe Pipes ") === 0 ||
                name.indexOf("DeepPipe Mock ") === 0;
    }

    function detachPredictionLayer() {
        if (qgisProject) {
            var projectLayers = ProjectUtils.mapLayers(qgisProject);
            Object.keys(projectLayers || {}).forEach(function (layerId) {
                var layer = projectLayers[layerId];
                if (layer === predictionResultLayer || isManagedPredictionLayer(layer)) {
                    ProjectUtils.removeMapLayer(qgisProject, layer);
                }
            });
        }
        predictionResultLayer = null;
        predictionExportGeoJson = "";
        predictionExportCrs = null;
        predictionAttributeTable = ({ columns: [], rows: [] });
        predictionResultLayerName = "";
        predictionResultPath = "";
        lastPredictionExportPath = "";
        hasPredictedResultGeometry = false;
        hasPotentialResultGeometry = false;
        focusedResultVisible = false;
        focusResultTimer.stop();
        predictedResultOverlay.geometryWrapper.clear();
        potentialResultOverlay.geometryWrapper.clear();
        focusedResultOverlay.geometryWrapper.clear();
        mapLayerVisibilityRevision += 1;
    }

    function removePredictionLayer(preserveCompletedJob, preserveStoredResult) {
        detachPredictionLayer();
        predictionSummary = null;
        if (!preserveCompletedJob) lastCompletedJobId = "";
        if (!preserveStoredResult) clearPredictionResultState();
    }

    function predictionResultFilePath() {
        if (!qgisProject || !hasProject) return "";
        var baseFolder = String(qgisProject.homePath || "");
        if (!baseFolder && projectPath) {
            var normalizedPath = String(projectPath).replace(/\\/g, "/");
            var separator = normalizedPath.lastIndexOf("/");
            if (separator > 0) baseFolder = normalizedPath.slice(0, separator);
        }
        if (!baseFolder) {
            baseFolder = String(StandardPaths.writableLocation(StandardPaths.DocumentsLocation) || "");
        }
        if (!baseFolder) return "";
        var projectHash = DeepPipe.stableHash(currentProjectKey).toString(36);
        return baseFolder + "/DeepPipe_prediction_latest_" + projectHash + ".geojson";
    }

    function setPredictionOverlayWkts(renderer, wkts, crs) {
        renderer.geometryWrapper.clear();
        if (!Array.isArray(wkts) || wkts.length === 0) return false;
        var wkt = wkts.length === 1
                ? String(wkts[0])
                : "GEOMETRYCOLLECTION (" + wkts.join(", ") + ")";
        var geometry = GeometryUtils.createGeometryFromWkt(wkt);
        if (!geometry) return false;
        renderer.geometryWrapper.crs = crs;
        renderer.geometryWrapper.qgsGeometry = geometry;
        return true;
    }

    function rebuildPredictionStateFromLayer(layer, selectedCount, threshold) {
        if (!layer || !layer.isValid) return false;
        var rawNames = layer.fields ? layer.fields.names : [];
        if (typeof rawNames === "function") rawNames = rawNames();
        var names = DeepPipe.stringList(rawNames);
        var preferred = [
            "deeppipe_outcome", "node_u", "node_v", "prob", "length",
            "class", "model_class", "sample_id", "link_id", "job_id"
        ];
        var orderedNames = [];
        preferred.forEach(function (name) {
            if (names.indexOf(name) >= 0 && orderedNames.indexOf(name) < 0) orderedNames.push(name);
        });
        names.forEach(function (name) {
            if (orderedNames.indexOf(name) < 0) orderedNames.push(name);
        });

        var rows = [];
        var predictedWkts = [];
        var potentialWkts = [];
        var iterator = LayerUtils.createFeatureIterator(layer);
        while (iterator && iterator.hasNext()) {
            var feature = iterator.next();
            if (!feature) continue;
            var row = { __row: rows.length + 1, __fid: Number(feature.id) };
            orderedNames.forEach(function (fieldName) {
                row[fieldName] = feature.attribute(fieldName);
            });
            rows.push(row);
            var outcome = String(row.deeppipe_outcome || "").toLowerCase();
            if (feature.geometry && typeof feature.geometry.asWkt === "function") {
                var featureWkt = String(feature.geometry.asWkt());
                if (outcome === "predicted") predictedWkts.push(featureWkt);
                if (outcome === "potential") potentialWkts.push(featureWkt);
            }
        }
        if (iterator && typeof iterator.close === "function") iterator.close();
        if (rows.length === 0) return false;

        predictionAttributeTable = {
            columns: [{ key: "__row", label: "Row" }].concat(
                         orderedNames.map(function (name) {
                             return { key: name, label: DeepPipe.predictionAttributeLabel(name) };
                         })),
            rows: rows
        };
        hasPredictedResultGeometry = setPredictionOverlayWkts(
                    predictedResultOverlay, predictedWkts, layer.crs);
        hasPotentialResultGeometry = setPredictionOverlayWkts(
                    potentialResultOverlay, potentialWkts, layer.crs);
        predictionSummary = {
            total: predictedWkts.length + potentialWkts.length,
            predicted: predictedWkts.length,
            potential: potentialWkts.length,
            unknown: 0,
            excluded: 0,
            selectedInlets: Math.max(0, Number(selectedCount || 0)),
            threshold: Number(threshold || predictionConfig.classification_threshold)
        };
        return true;
    }

    function rectangleNumber(rectangle, memberName) {
        if (!rectangle) return NaN;
        var value = rectangle[memberName];
        if (typeof value === "function") value = value.call(rectangle);
        return Number(value);
    }

    function attachPersistentPredictionLayer(path, state) {
        var layer = LayerUtils.loadVectorLayer(
                    String(path || ""),
                    "DeepPipe Prediction Results",
                    "ogr");
        if (!layer || !layer.isValid) return false;
        layer.opacity = 0;
        if (typeof layer.setCustomProperty === "function") {
            layer.setCustomProperty("deeppipe/managed_prediction_result", true);
            layer.setCustomProperty("deeppipe/result_path", String(path || ""));
        }
        if (!ProjectUtils.addMapLayer(qgisProject, layer)) return false;

        predictionResultLayer = layer;
        predictionResultLayerName = "DeepPipe Prediction Results";
        predictionResultPath = String(path || "");
        predictionExportCrs = layer.crs;
        lastPredictionExportPath = predictionResultPath;
        lastCompletedJobId = String(state && state.job_id || "");
        if (!rebuildPredictionStateFromLayer(
                    layer,
                    Number(state && state.selected_count || 0),
                    Number(state && state.threshold || predictionConfig.classification_threshold))) {
            ProjectUtils.removeMapLayer(qgisProject, layer);
            detachPredictionLayer();
            return false;
        }
        mapLayerVisibilityRevision += 1;
        return true;
    }

    function restorePersistedPredictionResult() {
        var state = savedPredictionResultState();
        if (!state || !state.path || !qgisProject) return false;
        detachPredictionLayer();
        if (!attachPersistentPredictionLayer(state.path, state)) {
            clearPredictionResultState();
            iface.logMessage("DeepPipe Mobile could not restore the saved prediction result at " + state.path);
            return false;
        }
        predictionExportGeoJson = "";
        predictionStatus = "succeeded";
        predictionMessage = "Restored the latest saved prediction result for this project.";
        return true;
    }

    function createPredictionResultLayer(featureCollection, crs, jobId, threshold, selectedCount) {
        if (!featureCollection || !Array.isArray(featureCollection.features) ||
                featureCollection.features.length === 0 || !qgisProject) {
            return false;
        }

        var partitions = DeepPipe.partitionPredictionResults(featureCollection, threshold);
        var decoratedCollection = {
            type: "FeatureCollection",
            crs: featureCollection.crs,
            features: partitions.predicted.features
                      .concat(partitions.potential.features)
        };
        decoratedCollection.features.forEach(function (feature, index) {
            if (!feature.properties) feature.properties = {};
            feature.properties.deeppipe_result_id = index + 1;
        });
        if (decoratedCollection.features.length === 0) return false;

        var requestedPath = predictionResultFilePath();
        if (!requestedPath) return false;
        var previousState = savedPredictionResultState();
        var stagingLayer = LayerUtils.memoryLayerFromJsonString(
                    "DeepPipe result staging",
                    JSON.stringify(decoratedCollection),
                    crs);
        if (!stagingLayer || !stagingLayer.isValid) return false;

        detachPredictionLayer();
        stagingLayer.opacity = 0;
        if (!ProjectUtils.addMapLayer(qgisProject, stagingLayer)) {
            if (previousState && previousState.path) {
                attachPersistentPredictionLayer(previousState.path, previousState);
            }
            return false;
        }
        var savedPath = LayerUtils.saveVectorLayerAs(stagingLayer, requestedPath, "GeoJSON", "");
        ProjectUtils.removeMapLayer(qgisProject, stagingLayer);
        if (!savedPath) {
            if (previousState && previousState.path) attachPersistentPredictionLayer(previousState.path, previousState);
            return false;
        }

        var nextState = {
            path: String(savedPath),
            layer_name: "DeepPipe Prediction Results",
            job_id: String(jobId || ""),
            threshold: Number(threshold || predictionConfig.classification_threshold),
            selected_count: Math.max(0, Number(selectedCount || 0))
        };
        if (!attachPersistentPredictionLayer(savedPath, nextState)) return false;
        predictionExportGeoJson = JSON.stringify(decoratedCollection);
        predictionExportCrs = crs;
        lastCompletedJobId = String(jobId || "");
        savePredictionResultState(savedPath, jobId, threshold, selectedCount);
        return true;
    }

    function exportPredictionResult() {
        if ((!predictionExportGeoJson || !predictionExportCrs) && predictionResultPath) {
            lastPredictionExportPath = predictionResultPath;
            toast("The latest result is already saved in this project's folder.");
            return;
        }
        if (!predictionExportGeoJson || !predictionExportCrs || !qgisProject) {
            toast("There is no prediction result to export.");
            return;
        }
        var baseFolder = String(qgisProject.homePath || "");
        if (!baseFolder) baseFolder = String(StandardPaths.writableLocation(StandardPaths.DocumentsLocation) || "");
        if (!baseFolder) {
            toast("QField could not find a writable export folder on this device.");
            return;
        }
        var filePart = DeepPipe.safeFilePart(lastCompletedJobId, "result-" + Date.now());
        var requestedPath = baseFolder + "/DeepPipe_prediction_" + filePart + ".geojson";
        var exportLayer = LayerUtils.memoryLayerFromJsonString(
                    "DeepPipe export " + filePart,
                    predictionExportGeoJson,
                    predictionExportCrs);
        if (!exportLayer || !exportLayer.isValid || !ProjectUtils.addMapLayer(qgisProject, exportLayer)) {
            toast("QField could not prepare the combined prediction result for export.");
            return;
        }
        exportLayer.opacity = 0;
        var savedPath = LayerUtils.saveVectorLayerAs(exportLayer, requestedPath, "GeoJSON", "");
        ProjectUtils.removeMapLayer(qgisProject, exportLayer);
        if (!savedPath) {
            toast("The prediction result could not be saved. Check project-folder write access.");
            return;
        }
        lastPredictionExportPath = String(savedPath);
        toast("Prediction result saved as GeoJSON.");
    }

    function sharePredictionExport() {
        if (!lastPredictionExportPath) return;
        if (typeof platformUtilities !== "undefined" && platformUtilities &&
                typeof platformUtilities.sendDatasetTo === "function") {
            platformUtilities.sendDatasetTo(lastPredictionExportPath);
            return;
        }
        toast("The GeoJSON is saved at " + lastPredictionExportPath);
    }

    function focusPredictionResult(rowIndex) {
        var rows = predictionAttributeTable && Array.isArray(predictionAttributeTable.rows)
                ? predictionAttributeTable.rows : [];
        var index = Number(rowIndex);
        if (!predictionResultLayer || !mapCanvas || !Number.isInteger(index) ||
                index < 0 || index >= rows.length) {
            toast("That prediction result is no longer available.");
            return;
        }
        var fid = Number(rows[index].__fid);
        if (!Number.isFinite(fid)) {
            toast("That prediction result does not have a usable feature ID.");
            return;
        }
        LayerUtils.selectFeaturesInLayer(predictionResultLayer, [fid]);
        var selected = typeof predictionResultLayer.selectedFeatures === "function"
                ? predictionResultLayer.selectedFeatures() : [];
        var feature = null;
        for (var selectedIndex = 0; selectedIndex < selected.length; selectedIndex += 1) {
            if (Number(selected[selectedIndex].id) === fid) {
                feature = selected[selectedIndex];
                break;
            }
        }
        if (!feature || !feature.geometry) {
            toast("QField could not locate that pipe geometry.");
            return;
        }

        focusedResultOverlay.geometryWrapper.crs = predictionResultLayer.crs;
        focusedResultOverlay.geometryWrapper.qgsGeometry = feature.geometry;
        focusedResultVisible = true;
        focusResultTimer.restart();
        if (geometryHighlighter && geometryHighlighter.geometryWrapper) {
            geometryHighlighter.geometryWrapper.crs = predictionResultLayer.crs;
            geometryHighlighter.geometryWrapper.qgsGeometry = feature.geometry;
        }

        var mapGeometry = GeometryUtils.reprojectGeometry(
                    feature.geometry,
                    predictionResultLayer.crs,
                    mapCanvas.mapSettings.destinationCrs);
        var extent = GeometryUtils.boundingBox(mapGeometry);
        var currentExtent = mapCanvas.mapSettings.extent;
        var featureSpan = Math.max(
                    rectangleNumber(extent, "width"),
                    rectangleNumber(extent, "height"));
        var viewSpan = currentExtent
                ? Math.max(
                      rectangleNumber(currentExtent, "width"),
                      rectangleNumber(currentExtent, "height")) : 0;
        var padding = Math.max(featureSpan * 0.25, viewSpan * 0.015);
        if (!Number.isFinite(padding) || padding <= 0) padding = 0.0005;
        var minimumX = rectangleNumber(extent, "xMinimum");
        var minimumY = rectangleNumber(extent, "yMinimum");
        var maximumX = rectangleNumber(extent, "xMaximum");
        var maximumY = rectangleNumber(extent, "yMaximum");
        if (![minimumX, minimumY, maximumX, maximumY].every(Number.isFinite)) {
            toast("The pipe was highlighted, but QField could not calculate its map extent.");
            return;
        }
        mapCanvas.mapSettings.extent = GeometryUtils.createRectangleFromPoints(
                    GeometryUtils.point(minimumX - padding, minimumY - padding),
                    GeometryUtils.point(maximumX + padding, maximumY + padding));
        toast("Focused pipe " + (index + 1) + " of " + rows.length + ".");
    }

    function downloadCompletedJobZip() {
        if (!appSettings.useLiveApi || !lastCompletedJobId) {
            toast("There is no completed live prediction ZIP to download.");
            return;
        }
        var path = "/api/jobs/jobs/" + encodeURIComponent(lastCompletedJobId) + "/download";
        var url = DeepPipe.apiUrl(defaultApiBaseUrl, path);
        if (!url) {
            toast("The completed-job download URL is invalid.");
            return;
        }
        Qt.openUrlExternally(url);
        toast("Opening the complete DeepPipe job ZIP in the device browser.");
    }

    function scheduleJobPoll(delayMs) {
        if (!activeJobId) return;
        jobPollTimer.interval = Math.max(300, Number(delayMs || 8000));
        jobPollTimer.restart();
    }

    function startLivePrediction() {
        var validation = DeepPipe.validateLiveSelectedPoints(selectedPoints);
        if (!validation.ok) {
            predictionStatus = "failed";
            predictionMessage = validation.errors[0].message;
            toast(predictionMessage);
            return;
        }
        if (activeJobId) {
            predictionStatus = "failed";
            predictionMessage = "Prediction job " + activeJobId + " is already active.";
            toast(predictionMessage);
            return;
        }
        if (!DeepPipe.normalizeApiBaseUrl(defaultApiBaseUrl)) {
            predictionStatus = "failed";
            predictionMessage = "The built-in Prediction service endpoint is invalid.";
            toast(predictionMessage);
            return;
        }

        var selectedCount = selectedPoints.length;
        var submittedThreshold = predictionConfig.classification_threshold;
        var featureCollection = DeepPipe.featureCollectionFromPoints(selectedPoints, nodeIdField);
        var requestBody = DeepPipe.buildPredictionRequest(
                    featureCollection,
                    nodeIdField,
                    predictionConfig,
                    {});

        predictionStatus = "submitting";
        predictionMessage = "Submitting " + selectedCount + " selected inlets to the DeepPipe API…";

        sendApiRequest("POST", "/api/pred/pred_deep", requestBody, 60000,
                       function (ok, payload, status, message) {
            if (!ok) {
                predictionStatus = "failed";
                predictionMessage = status === 0
                        ? "Submission could not be confirmed and was not retried automatically, to avoid a duplicate job. " + message
                        : message;
                toast(predictionMessage);
                return;
            }
            var jobId = payload ? String(payload.task_id || payload.job_id || "") : "";
            if (!jobId) {
                predictionStatus = "failed";
                predictionMessage = "The API accepted the request but did not return a task ID.";
                toast(predictionMessage);
                return;
            }

            activeJobId = jobId;
            activeJobProjectKey = currentProjectKey;
            activeJobProjectName = projectName;
            activeJobSelectedCount = selectedCount;
            activeJobThreshold = submittedThreshold;
            pollFailureCount = 0;
            predictionStatus = DeepPipe.normalizeJobStatus(payload.status || "queued");
            predictionMessage = "Prediction job " + activeJobId + " is queued. You can leave this panel; polling will resume after reopening the project.";
            apiConnectionStatus = "ok";
            apiConnectionMessage = "Connected · job accepted";
            persistActiveJob();
            scheduleJobPoll(1200);
        });
    }

    function pollActiveJob() {
        if (!activeJobId) return;
        if (activeRequest) {
            scheduleJobPoll(1500);
            return;
        }
        if ((activeJobProjectKey && activeJobProjectKey !== currentProjectKey) ||
                (!activeJobProjectKey && activeJobProjectName && activeJobProjectName !== projectName)) {
            predictionStatus = "queued";
            predictionMessage = "Saved job " + activeJobId + " belongs to project '" + activeJobProjectName + "'.";
            return;
        }
        var jobId = activeJobId;
        sendApiRequest("GET", "/api/jobs/jobs/" + encodeURIComponent(jobId) + "/status", null, 30000,
                       function (ok, payload, status, message) {
            if (!activeJobId || activeJobId !== jobId) return;
            if (!ok) {
                pollFailureCount += 1;
                predictionMessage = "Job " + jobId + " is still saved, but its status could not be refreshed: " + message;
                scheduleJobPoll(Math.min(60000, 8000 * Math.pow(1.7, pollFailureCount)));
                return;
            }

            pollFailureCount = 0;
            var normalized = DeepPipe.normalizeJobStatus(payload && (payload.status || payload.state));
            var progressMessage = DeepPipe.statusMessage(payload);
            if (normalized === "succeeded") {
                fetchLiveResultFiles(jobId);
                return;
            }
            if (normalized === "failed" || normalized === "cancelled") {
                predictionStatus = normalized;
                predictionMessage = progressMessage || ("Prediction job " + jobId + " " + normalized + ".");
                clearActiveJob();
                toast(predictionMessage);
                return;
            }

            predictionStatus = normalized === "unknown" ? "running" : normalized;
            predictionMessage = "Job " + jobId + (progressMessage ? " · " + progressMessage : " · " + predictionStatus);
            scheduleJobPoll(predictionStatus === "queued" ? 6000 : 10000);
        });
    }

    function fetchLiveResultFiles(jobId) {
        predictionStatus = "fetching";
        predictionMessage = "Prediction completed. Locating the pipe result…";
        sendApiRequest("GET", "/api/jobs/jobs/" + encodeURIComponent(jobId) + "/files", null, 30000,
                       function (ok, payload, status, message) {
            if (!activeJobId || activeJobId !== jobId) return;
            if (!ok) {
                predictionMessage = "Job completed, but its result list is not available yet: " + message;
                scheduleJobPoll(12000);
                return;
            }
            var filename = DeepPipe.choosePipeResultFilename(
                        payload && payload.files !== undefined ? payload.files : payload);
            if (!filename) {
                predictionMessage = "Job completed, but no pipe GeoJSON is available yet.";
                scheduleJobPoll(12000);
                return;
            }
            fetchLivePipeGeoJson(jobId, filename);
        });
    }

    function fetchLivePipeGeoJson(jobId, filename) {
        predictionStatus = "fetching";
        predictionMessage = "Downloading " + filename + "…";
        var path = "/api/jobs/jobs/" + encodeURIComponent(jobId) + "/geojson/" + encodeURIComponent(filename);
        sendApiRequest("GET", path, null, 45000, function (ok, payload, status, message) {
            if (!activeJobId || activeJobId !== jobId) return;
            if (!ok) {
                predictionMessage = "Job completed, but the pipe layer could not be downloaded: " + message;
                scheduleJobPoll(15000);
                return;
            }
            if (!payload || payload.type !== "FeatureCollection" || !Array.isArray(payload.features)) {
                predictionMessage = "The API returned an invalid pipe GeoJSON result.";
                scheduleJobPoll(15000);
                return;
            }

            var result = DeepPipe.decorateLiveResult(payload, jobId, activeJobThreshold);
            var summary = DeepPipe.summarizeLiveResult(result, activeJobSelectedCount, activeJobThreshold);
            if (summary.total === 0) {
                removePredictionLayer(false, false);
                lastCompletedJobId = jobId;
                predictionSummary = summary;
                predictionStatus = "succeeded";
                predictionMessage = "Live API job " + jobId + " completed, but it returned no above-threshold GNN candidates with a final MST class.";
                clearActiveJob();
                toast("DeepPipe prediction completed with no returned pipes.");
                return;
            }

            if (!createPredictionResultLayer(
                        result,
                        CoordinateReferenceSystemUtils.wgs84Crs(),
                        jobId,
                        activeJobThreshold,
                        activeJobSelectedCount)) {
                predictionStatus = "fetching";
                predictionMessage = "The live result was downloaded but could not be added to the map. The job ID remains saved for retry.";
                scheduleJobPoll(20000);
                return;
            }

            lastCompletedJobId = jobId;
            predictionSummary = summary;
            predictionStatus = "succeeded";
            predictionMessage = "Live API job " + jobId + " added " + summary.predicted + " Predicted and " + summary.potential + " Potential pipe" + (summary.total === 1 ? "" : "s") + " to the map.";
            clearActiveJob();
            toast("DeepPipe live prediction is ready.");
        });
    }

    function cancelLivePrediction() {
        if (!activeJobId) return;
        var jobId = activeJobId;
        jobPollTimer.stop();
        predictionStatus = "cancelling";
        predictionMessage = "Cancelling prediction job " + jobId + "…";
        sendApiRequest("POST", "/api/jobs/jobs/" + encodeURIComponent(jobId) + "/cancel", null, 30000,
                       function (ok, payload, status, message) {
            if (!activeJobId || activeJobId !== jobId) return;
            if (!ok || (payload && payload.error)) {
                predictionStatus = "running";
                predictionMessage = "Cancellation was not confirmed: " + (message || DeepPipe.apiErrorMessage(payload, status, "Unknown cancellation error"));
                scheduleJobPoll(5000);
                return;
            }
            predictionStatus = "cancelled";
            predictionMessage = String((payload && payload.message) || ("Prediction job " + jobId + " was cancelled."));
            clearActiveJob();
            toast(predictionMessage);
        });
    }

    function startPrediction() {
        if (!projectReady) {
            predictionStatus = "failed";
            predictionMessage = setupMessage;
            toast(setupMessage);
            return;
        }
        if (appSettings.useLiveApi) startLivePrediction();
        else startMockPrediction();
    }

    function startMockPrediction() {
        var validation = DeepPipe.validateSelectedPoints(selectedPoints);
        if (!validation.ok) {
            predictionStatus = "failed";
            predictionMessage = validation.errors[0].message;
            toast(predictionMessage);
            return;
        }

        activeMockJobId = DeepPipe.createMockJobId(selectedPoints, Date.now());
        predictionStatus = "queued";
        predictionMessage = "Preparing " + selectedPoints.length + " locally selected inlets…";
        predictionSummary = null;
        mockPredictionStage = 0;
        mockPredictionTimer.restart();
    }

    function completeMockPrediction() {
        var result = DeepPipe.buildMockPrediction(selectedPoints, predictionConfig, activeMockJobId);
        if (!result.ok) {
            predictionStatus = "failed";
            predictionMessage = result.validation.errors[0].message;
            return;
        }

        if (!createPredictionResultLayer(
                    result.featureCollection,
                    inletLayer.crs,
                    activeMockJobId,
                    predictionConfig.classification_threshold,
                    selectedPoints.length)) {
            predictionStatus = "failed";
            predictionMessage = "The preview was generated but could not be added to the map.";
            return;
        }

        lastCompletedJobId = activeMockJobId;
        predictionSummary = result.summary;
        predictionStatus = "succeeded";
        predictionMessage = "Deterministic mock network added to the map. No production model was called.";
        toast("DeepPipe mock prediction is ready.");
    }

    Connections {
        target: iface

        function onLoadProjectEnded(path, name) {
            loadProjectConfiguration(true);
        }

        function onLoadProjectTriggered(path, name) {
            interactionMode = "idle";
            panelDrawer.close();
            mockPredictionTimer.stop();
            jobPollTimer.stop();
            abandonActiveRequest();
            releasePointHandler();
            detachPredictionLayer();
            removeManagedRasterLayers();
            selectedFids = [];
            selectedPoints = [];
            inletLayer = null;
        }
    }

    Connections {
        target: inletLayer
        ignoreUnknownSignals: true

        function onSelectionChanged(selected, deselected, clearAndSelect) {
            if (!selectionMutationInProgress && interactionMode !== "select_inlets") {
                syncFromNativeSelection();
            }
        }
    }

    Connections {
        target: Qt.application
        ignoreUnknownSignals: true

        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive && activeJobId) {
                scheduleJobPoll(300);
            } else if (Qt.application.state !== Qt.ApplicationActive) {
                jobPollTimer.stop();
                if (activeJobId) persistActiveJob();
            }
        }
    }

    Connections {
        target: mapCanvas && mapCanvas.mapSettings ? mapCanvas.mapSettings : null
        ignoreUnknownSignals: true

        function onLayersChanged() {
            mapLayerVisibilityRevision += 1;
        }
    }

    Timer {
        id: mockPredictionTimer
        interval: 650
        repeat: true

        onTriggered: {
            mockPredictionStage += 1;
            if (mockPredictionStage === 1) {
                predictionStatus = "running";
                predictionMessage = "Building a deterministic connectivity preview…";
            } else {
                stop();
                completeMockPrediction();
            }
        }
    }

    Timer {
        id: jobPollTimer
        interval: 8000
        repeat: false
        onTriggered: pollActiveJob()
    }

    Timer {
        id: focusResultTimer
        interval: 4500
        repeat: false
        onTriggered: {
            focusedResultVisible = false;
            focusedResultOverlay.geometryWrapper.clear();
        }
    }

    QfToolButton {
        id: pluginButton
        objectName: "deepPipeMobileButton"
        iconSource: "icon.svg"
        // UNC Charlotte digital palette: Charlotte Green with a Quartz White icon.
        iconColor: "#FFFFFF"
        bgcolor: "#005035"
        round: true

        onClicked: {
            loadProjectConfiguration(false);
            panelDrawer.open();
        }
    }

    QfToolButton {
        id: resultTableButton
        objectName: "deepPipePredictionResultsButton"
        iconSource: "results-table.svg"
        iconColor: "#FFFFFF"
        bgcolor: "#005035"
        round: true
        visible: predictionResultLayer !== null && predictionAttributeTable &&
                 Array.isArray(predictionAttributeTable.rows) &&
                 predictionAttributeTable.rows.length > 0
        Accessible.name: "Open DeepPipe prediction results table"

        onClicked: deepPipePanel.openResultAttributeTable()
    }

    Drawer {
        id: panelDrawer
        parent: mainWindow ? mainWindow.contentItem : plugin
        edge: Qt.RightEdge
        modal: true
        interactive: interactionMode === "idle"
        width: parent ? Math.min(parent.width, parent.width > parent.height ? 560 : parent.width) : 420
        height: parent ? parent.height : 720

        DeepPipePanel {
            id: deepPipePanel
            anchors.fill: parent
            mainWindow: plugin.mainWindow
            hasProject: plugin.hasProject
            projectReady: plugin.projectReady
            assessmentReady: plugin.assessmentReady
            projectName: plugin.projectName
            setupState: plugin.setupState
            setupMessage: plugin.setupMessage
            layerNames: plugin.layerNames
            layerIds: plugin.layerIds
            inletLayerId: plugin.inletLayerId
            inletLayerName: plugin.inletLayerName
            fieldNames: plugin.fieldNames
            nodeIdField: plugin.nodeIdField
            mappingConfirmed: plugin.mappingConfirmed
            selectedCount: plugin.selectedPoints.length
            inletSelectionActive: plugin.interactionMode === "select_inlets"
            predictionStatus: plugin.predictionStatus
            predictionMessage: plugin.predictionMessage
            predictionSummary: plugin.predictionSummary
            predictionResultLayer: plugin.predictionResultLayerName
            predictionExportPath: plugin.lastPredictionExportPath
            predictionAttributeTable: plugin.predictionAttributeTable
            completedJobId: plugin.lastCompletedJobId
            predictionConfig: plugin.predictionConfig
            maxSearchRadius: plugin.predictionConfig.max_search_radius
            confidenceThreshold: plugin.predictionConfig.classification_threshold
            assessmentLocationLabel: plugin.assessmentLocationLabel
            assessmentStatus: plugin.assessmentStatus
            assessmentMessage: plugin.assessmentMessage
            assessmentResult: plugin.assessmentResult
            assessmentNominalDiameter: plugin.assessmentNominalDiameter
            assessmentGauge: plugin.assessmentGauge
            assessmentMaterialId: plugin.assessmentMaterialId
            assessmentGaugeOptions: DeepPipe.passGaugeOptions(plugin.assessmentMaterialId)
            assessmentMaterialRequiresGauge: DeepPipe.passMaterialById(plugin.assessmentMaterialId).requires_gauge
            assessmentMaterialName: DeepPipe.passMaterialById(plugin.assessmentMaterialId).name
            assessmentMinimumYears: plugin.assessmentMinimumYears
            mockMode: !appSettings.useLiveApi
            apiConnectionStatus: plugin.apiConnectionStatus
            apiConnectionMessage: plugin.apiConnectionMessage
            passApiConnectionStatus: plugin.passApiConnectionStatus
            passApiConnectionMessage: plugin.passApiConnectionMessage
            rasterStatus: plugin.rasterStatus
            rasterMessage: plugin.rasterMessage
            rasterLayerNames: plugin.managedRasterLayerNames
            activeJobId: plugin.activeJobId
            pluginVersion: plugin.pluginVersion

            onCloseRequested: panelDrawer.close()
            onRefreshProjectRequested: plugin.loadProjectConfiguration(false)
            onInletLayerRequested: function (layerId) { plugin.chooseInletLayer(layerId); }
            onNodeIdFieldRequested: function (fieldName) { plugin.chooseNodeIdField(fieldName); }
            onConfirmProjectMappingRequested: plugin.confirmProjectMapping()
            onSelectInletsRequested: plugin.startInletSelection()
            onFinishSelectionRequested: plugin.finishMapInteraction()
            onClearSelectionRequested: plugin.clearSelectedInlets()
            onPredictionSettingsRequested: function (settings) {
                var nextConfig = {};
                for (var key in plugin.predictionConfig) nextConfig[key] = plugin.predictionConfig[key];
                for (var settingKey in settings) nextConfig[settingKey] = settings[settingKey];
                plugin.setPredictionConfig(nextConfig);
            }
            onRunPredictionRequested: plugin.startPrediction()
            onCancelPredictionRequested: plugin.cancelLivePrediction()
            onRemovePredictionLayerRequested: plugin.removePredictionLayer(true)
            onExportPredictionRequested: plugin.exportPredictionResult()
            onSharePredictionExportRequested: plugin.sharePredictionExport()
            onDownloadPredictionZipRequested: plugin.downloadCompletedJobZip()
            onPredictionRowRequested: function (rowIndex) {
                panelDrawer.close();
                plugin.focusPredictionResult(rowIndex);
            }
            onPickAssessmentLocationRequested: plugin.startAssessmentLocationSelection()
            onUseGnssRequested: plugin.useCurrentGnssLocation()
            onAssessmentInputsRequested: function (diameter, gauge, materialId, minimumYears) {
                plugin.setAssessmentInputs(diameter, gauge, materialId, minimumYears);
            }
            onRunAssessmentRequested: plugin.runLiveAssessment()
            onAddPassVariableRasterRequested: function (variableId, name) {
                plugin.addPassVariableRaster(variableId, name);
            }
            onAddPassServiceLifeRasterRequested: plugin.addPassServiceLifeRaster()
            onRemoveRasterLayersRequested: plugin.removeManagedRasterLayers()
            onTestApiRequested: plugin.testApiConnections()
        }
    }

    // QField's point handler is the preferred single-tap path, but an overlay
    // makes selection deterministic on QField builds where the handler is not
    // exposed to app-wide plugins. It also gives drag selection one coordinate
    // system for both mouse and touch devices.
    Item {
        id: mapInteractionOverlay
        parent: mapCanvas ? mapCanvas : plugin
        anchors.fill: parent
        visible: interactionMode === "select_inlets" || interactionMode === "assessment_location"
        enabled: visible
        z: 9999

        MouseArea {
            id: mapInteractionArea
            anchors.fill: parent
            preventStealing: true
            property point dragStart: Qt.point(0, 0)
            property point dragCurrent: Qt.point(0, 0)
            property bool dragging: false

            onPressed: function (mouse) {
                if (interactionMode !== "select_inlets" || inletSelectionMode !== "box") return;
                dragStart = Qt.point(mouse.x, mouse.y);
                dragCurrent = dragStart;
                dragging = true;
            }
            onPositionChanged: function (mouse) {
                if (dragging) dragCurrent = Qt.point(mouse.x, mouse.y);
            }
            onCanceled: dragging = false
            onClicked: function (mouse) {
                var screenPoint = Qt.point(mouse.x, mouse.y);
                if (interactionMode === "assessment_location") {
                    handleAssessmentMapTap(screenPoint);
                } else if (inletSelectionMode === "tap") {
                    handleInletMapTap(screenPoint);
                }
            }
            onReleased: function (mouse) {
                if (!dragging) return;
                dragCurrent = Qt.point(mouse.x, mouse.y);
                var dragWidth = Math.abs(dragCurrent.x - dragStart.x);
                var dragHeight = Math.abs(dragCurrent.y - dragStart.y);
                dragging = false;
                if (dragWidth < 10 || dragHeight < 10) {
                    toast("Drag a larger rectangle, or switch to Tap mode for one inlet.");
                    return;
                }
                addInletsInScreenRectangle(dragStart, dragCurrent, "Box selection");
            }
        }

        Rectangle {
            visible: mapInteractionArea.dragging
            x: Math.min(mapInteractionArea.dragStart.x, mapInteractionArea.dragCurrent.x)
            y: Math.min(mapInteractionArea.dragStart.y, mapInteractionArea.dragCurrent.y)
            width: Math.abs(mapInteractionArea.dragCurrent.x - mapInteractionArea.dragStart.x)
            height: Math.abs(mapInteractionArea.dragCurrent.y - mapInteractionArea.dragStart.y)
            color: "#33005035"
            border.color: "#005035"
            border.width: 2
            radius: 3
        }
    }

    Rectangle {
        id: inletSelectionBar
        parent: mainWindow ? mainWindow.contentItem : plugin
        visible: interactionMode === "select_inlets"
        z: 10000
        height: 138
        width: parent ? Math.min(parent.width - 20, 640) : 360
        x: parent ? (parent.width - width) / 2 : 10
        y: parent ? parent.height - height - 14 : 620
        radius: 18
        color: "#F7FBF9"
        border.color: "#96C9B9"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: selectedPoints.length + " inlet" + (selectedPoints.length === 1 ? "" : "s") + " selected"
                    color: "#17332E"
                    font.pixelSize: 16
                    font.bold: true
                }
                Button {
                    Layout.preferredWidth: 82
                    Layout.preferredHeight: 46
                    text: "Done"
                    font.bold: true
                    palette.button: "#087565"
                    palette.buttonText: "white"
                    onClicked: finishMapInteraction()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    text: "Tap"
                    checkable: true
                    checked: inletSelectionMode === "tap"
                    Accessible.name: "Select individual inlets"
                    onClicked: setInletSelectionMode("tap")
                }
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    text: "Box"
                    checkable: true
                    checked: inletSelectionMode === "box"
                    Accessible.name: "Select inlets by dragging a rectangle"
                    onClicked: setInletSelectionMode("box")
                }
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    text: "Visible"
                    Accessible.name: "Select all visible inlets"
                    onClicked: selectVisibleInlets()
                }
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    text: "Clear"
                    enabled: selectedPoints.length > 0
                    onClicked: clearSelectedInlets()
                }
            }
        }
    }

    Rectangle {
        id: assessmentSelectionBar
        parent: mainWindow ? mainWindow.contentItem : plugin
        visible: interactionMode === "assessment_location"
        z: 10000
        height: 72
        width: parent ? Math.min(parent.width - 20, 500) : 360
        x: parent ? (parent.width - width) / 2 : 10
        y: parent ? parent.height - height - 14 : 626
        radius: 18
        color: "#F7FBF9"
        border.color: "#96C9B9"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: "Tap the assessment location"
                color: "#17332E"
                font.pixelSize: 15
                font.bold: true
            }
            Button {
                Layout.preferredWidth: 88
                Layout.preferredHeight: 50
                text: "Cancel"
                onClicked: cancelMapInteraction()
            }
        }
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(pluginButton);
        iface.addItemToCanvasActionsToolbar(resultTableButton);
        loadProjectConfiguration(true);
    }

    Component.onDestruction: {
        mockPredictionTimer.stop();
        jobPollTimer.stop();
        abandonActiveRequest();
        releasePointHandler();
        detachPredictionLayer();
        removeManagedRasterLayers();
    }
}
