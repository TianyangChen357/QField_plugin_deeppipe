import QtQuick
import QtQuick.Controls
import QtTest
import "../runtime" as Plugin

// The runner copies shipped sources unchanged except replacing the qrc:/qml
// import with the test GeometryRenderer. QField/QGIS APIs below are explicit
// host fakes; real Qt parses the entire runtime and runs its actual methods.
Item {
    id: host
    width: 720
    height: 1000
    property var contentItem: host
    property var qgisProject: null
    property var requests: []
    property var toasts: []
    property var logs: []
    function displayToast(text) { toasts.push(text); }

    Item {
        id: canvas
        anchors.fill: parent
        property QtObject mapSettings: QtObject {
            property var layers: []
            property var destinationCrs: "EPSG:4326"
            function screenToCoordinate(point) { return {x: -80 + point.x / 100000, y: 35 + point.y / 100000}; }
        }
    }
    QtObject {
        id: iface
        signal loadProjectTriggered(string path, string name)
        signal loadProjectEnded(string path, string name)
        function mainWindow() { return host; }
        function mapCanvas() { return canvas; }
        function positioning() { return null; }
        function findItemByObjectName(name) { return null; }
        function logMessage(text) { host.logs.push(text); }
        function readProjectEntry(section, key, fallback) { return fallback; }
        function addItemToPluginsToolbar(item) {}
        function addItemToCanvasActionsToolbar(item) {}
        function createHttpRequest() {
            return {
                status: 0, responseText: "", headers: {}, aborted: false,
                open: function(method, url) { this.method = method; this.url = url; },
                setRequestHeader: function(name, value) { this.headers[name] = value; },
                send: function(body) { this.body = body === undefined ? null : JSON.parse(body); host.requests.push(this); },
                abort: function() { this.aborted = true; if (this.onaborted) this.onaborted(); }
            };
        }
    }
    Component { id: pluginFactory; Plugin.Main {} }
    Component {
        id: capturedMapInstallFactory
        Plugin.Main {
            // TEST ONLY: capture the runtime's final map-install boundary.
            // The download/decorate/summary/commit methods remain unchanged;
            // no native QgsVectorLayer or actual disk dataset is created here.
            property var testInstalledCollection: null
            function createPredictionResultLayer(collection, crs, jobId, threshold, selectedCount) {
                testInstalledCollection = collection;
                return true;
            }
        }
    }

    TestCase {
        id: test
        name: "DeepPipeRuntimeWithHostFakes"
        when: windowShown
        property var plugin
        property var nodes: ({type: "FeatureCollection", features: [
            {type: "Feature", properties: {node_id: "A"}, geometry: {type: "Point", coordinates: [-80, 35]}},
            {type: "Feature", properties: {node_id: "B"}, geometry: {type: "Point", coordinates: [-79.999, 35]}},
            {type: "Feature", properties: {node_id: "C"}, geometry: {type: "Point", coordinates: [-79.999, 35.001]}},
            {type: "Feature", properties: {node_id: "D"}, geometry: {type: "Point", coordinates: [-80, 35.001]}}
        ]})
        property var candidates: ({type: "FeatureCollection", features: [
            {type: "Feature", properties: {node_u: "A", node_v: "B", prob: 0.8, model_prob: 0.8, class: 1}, geometry: {type: "LineString", coordinates: [[-80, 35], [-79.999, 35]]}},
            {type: "Feature", properties: {node_u: "B", node_v: "C", prob: 0.4, model_prob: 0.4, class: 0}, geometry: {type: "LineString", coordinates: [[-79.999, 35], [-79.999, 35.001]]}}
        ]})

        function initTestCase() {
            // QSettings needs application identity, normally supplied by the
            // QField host. Use a disposable settings directory from the runner.
            Qt.application.organization = "DeepPipeTests";
            Qt.application.domain = "deeppipe.test";
            Qt.application.name = "QFieldRuntimeTests";
        }

        function init() {
            host.requests = [];
            host.toasts = [];
            host.logs = [];
            plugin = createTemporaryObject(pluginFactory, host, {width: host.width, height: host.height});
            verify(plugin !== null, "The complete shipped runtime compiles in native Qt with declared host fakes");
            plugin.hasProject = true;
            plugin.projectPath = "/test/project-a.qgs";
            plugin.projectName = "Project A";
            plugin.currentProjectKey = "path:/test/project-a.qgs";
            plugin.lastCompletedJobId = "parent-job";
            plugin.predictionStatus = "succeeded";
            plugin.resultInputNodes = JSON.parse(JSON.stringify(nodes));
            plugin.resultCandidates = JSON.parse(JSON.stringify(candidates));
            plugin.resultNodeIdField = "node_id";
            plugin.resultWorkflowType = "progressive";
            plugin.resultPredictionConfig = {workflow_type: "progressive", model_type: "progressive_gnn",
                progressive_config: {neighbors_per_sector: 2, knn_k: 12, knn_max_distance_ft: 250, rounds: 3, use_msf: true}};
            plugin.savedObservations = [];
            plugin.observationDraft = [];
            plugin.predictionSummary = {total: 1, predicted: 1, selectedInlets: 4};
            plugin.refreshObservationReview(false);
            verify(plugin.canUpdateObservations);
        }

        function cleanup() {
            if (!plugin) return;
            plugin.abandonActiveRequest();
            plugin.clearActiveJob();
            plugin.clearPredictionResultState();
            plugin.visible = false;
        }

        function response(status, payload) {
            verify(host.requests.length > 0, "An actual runtime HTTP request was sent through the host fake");
            var request = host.requests[host.requests.length - 1];
            request.status = status;
            request.responseText = JSON.stringify(payload);
            request.onload();
            return request;
        }

        function request() { return host.requests[host.requests.length - 1]; }

        function acceptRefinement() {
            var parentApiBaseUrl = plugin.resultApiBaseUrl || plugin.defaultApiBaseUrl;
            plugin.updatePredictionFromObservations();
            compare(request().method, "POST");
            compare(request().url, parentApiBaseUrl + "/api/pred/jobs/parent-job/refine");
            response(202, {task_id: "child-job", status: "queued"});
            compare(plugin.activeJobId, "child-job");
        }

        function downloadResult(pipes) {
            plugin.pollActiveJob();
            response(200, {status: "succeeded"});
            verify(request().url.endsWith("/child-job/files"));
            response(200, {files: ["Structures.geojson", "Pipes.geojson", "Candidates.geojson"]});
            verify(request().url.endsWith("/geojson/Candidates.geojson"));
            response(200, candidates);
            verify(request().url.endsWith("/geojson/Pipes.geojson"));
            response(200, pipes);
        }

        function test_observationEditingPersistsAndUndoRestores() {
            plugin.changeObservation("D", "A", "connected");
            compare(plugin.observationDraft.length, 1);
            compare(plugin.observationDraft[0].node_u, "A");
            compare(plugin.observationDraft[0].node_v, "D");
            verify(plugin.observationDirty);
            compare(plugin.observationRows.length, 3, "Missing candidate pair is added for review");
            var stored = plugin.savedPredictionResultState();
            compare(stored.job_id, "parent-job");
            compare(stored.draft_observations[0].state, "connected");
            plugin.changeObservation("A", "B", "disconnected");
            compare(plugin.observationDraft.length, 2);
            plugin.undoObservation();
            compare(plugin.observationDraft.length, 1);
            plugin.changeObservation("A", "D", "unknown");
            compare(plugin.observationDraft.length, 0);
            compare(plugin.observationDirty, false);
            compare(plugin.savedPredictionResultState().draft_observations.length, 0);
        }

        function test_blueAndDashedRedGeometryArePopulated() {
            plugin.changeObservation("A", "D", "connected");
            plugin.changeObservation("A", "B", "disconnected");
            compare(plugin.observationOverlayVisible, true);
            compare(plugin.hasConnectedObservationGeometry, true);
            compare(plugin.hasDisconnectedObservationGeometry, true);
            var renderers = canvas.children.filter(function(item) { return item.geometryWrapper !== undefined; });
            var blue = renderers.filter(function(item) { return String(item.color) === "#075985"; })[0];
            var red = renderers.filter(function(item) { return String(item.color) === "#dc2626"; })[0];
            verify(blue !== undefined);
            verify(red !== undefined);
            verify(blue.geometryWrapper.qgsGeometry.wkt.indexOf("MULTILINESTRING") === 0);
            verify(red.geometryWrapper.qgsGeometry.wkt.indexOf("MULTILINESTRING") === 0);
            verify(red.geometryWrapper.qgsGeometry.wkt.split(/\)\s*,\s*\(/).length > 3, "Rejected pair is supplied as actual separated dash geometries");
            plugin.refreshObservationReview(false);
            compare(plugin.observationOverlayVisible, false, "Final green result can show without blue/red overlays");
        }

        function test_originalNodeMapTapsCanAddMissingCandidate() {
            plugin.selectedPoints = [];
            plugin.startObservationPairSelection();
            compare(plugin.interactionMode, "observation_pair");
            compare(plugin.handleObservationMapTap(Qt.point(0, 0)), true);
            compare(plugin.observationFirstNode, "A");
            wait(230); // Real runtime ignores double taps within 220 ms.
            compare(plugin.handleObservationMapTap(Qt.point(0, 100)), true);
            compare(plugin.interactionMode, "idle");
            compare(plugin.observationDraft.length, 1);
            compare(plugin.observationDraft[0].node_u, "A");
            compare(plugin.observationDraft[0].node_v, "D");
            compare(plugin.observationDraft[0].state, "connected");
            compare(plugin.observationRows.length, 3);
            compare(plugin.hasConnectedObservationGeometry, true);
        }

        function test_savedAndDraftObservationStateRoundTrips() {
            plugin.savedObservations = [{node_u: "A", node_v: "B", state: "connected"}];
            plugin.observationDraft = JSON.parse(JSON.stringify(plugin.savedObservations));
            plugin.changeObservation("A", "B", "disconnected");
            plugin.changeObservation("A", "D", "connected");
            var stored = JSON.parse(JSON.stringify(plugin.savedPredictionResultState()));
            plugin.clearObservationRuntime();
            compare(plugin.resultInputNodes, null);
            plugin.restoreObservationState(stored);
            compare(plugin.resultInputNodes.features.length, 4);
            compare(plugin.resultPredictionConfig.progressive_config.rounds, 3);
            compare(plugin.savedObservations[0].state, "connected");
            compare(plugin.observationDraft.length, 2);
            compare(plugin.observationDraft[0].state, "disconnected");
            compare(plugin.observationDirty, true);
            compare(plugin.observationOverlayVisible, true);
            compare(plugin.hasConnectedObservationGeometry, true);
            compare(plugin.hasDisconnectedObservationGeometry, true);
        }

        function test_refinementSendsWholeSnapshotAndOriginalInput() {
            plugin.changeObservation("A", "D", "connected");
            plugin.changeObservation("A", "B", "disconnected");
            // Changing the next selection/config must not replace the result's
            // immutable original input and config during a refinement.
            plugin.selectedPoints = [{nodeId: "different-input"}];
            plugin.predictionConfig = {progressive_config: {rounds: 9}};
            acceptRefinement();
            compare(request().body.observations.length, 2);
            compare(Object.keys(request().body).join(","), "observations");
            compare(plugin.activeJobSelectedCount, 4);
            compare(plugin.activeJobInputNodes.features[0].properties.node_id, "A");
            compare(plugin.activeJobConfig.progressive_config.rounds, 3);
            compare(plugin.activeJobParentId, "parent-job");
            compare(plugin.canUpdateObservations, false);
            var count = host.requests.length;
            plugin.updatePredictionFromObservations();
            compare(host.requests.length, count, "An accepted child blocks duplicate refinement submissions");
        }

        function test_removingAllObservationsSubmitsEmptySnapshot() {
            plugin.savedObservations = [{node_u: "A", node_v: "B", state: "connected"}];
            plugin.observationDraft = JSON.parse(JSON.stringify(plugin.savedObservations));
            plugin.replaceObservationDraft([]);
            acceptRefinement();
            compare(request().body.observations.length, 0);
        }

        function test_submissionFailurePreservesParentAndDraft() {
            plugin.changeObservation("A", "D", "connected");
            plugin.updatePredictionFromObservations();
            response(503, {detail: "temporary test failure"});
            compare(plugin.predictionStatus, "failed");
            compare(plugin.lastCompletedJobId, "parent-job");
            compare(plugin.observationDraft.length, 1);
            compare(plugin.savedObservations.length, 0);
            compare(plugin.activeJobId, "");
            compare(plugin.canUpdateObservations, true);
            compare(host.requests.length, 1, "A failed POST is not automatically retried");
        }

        function test_staleRefinementCallbackCannotAdoptAnotherProject() {
            plugin.changeObservation("A", "D", "connected");
            plugin.updatePredictionFromObservations();
            plugin.currentProjectKey = "path:/test/project-b.qgs";
            plugin.lastCompletedJobId = "project-b-parent";
            plugin.predictionStatus = "idle";
            response(202, {task_id: "stale-child", status: "queued"});
            compare(plugin.activeJobId, "");
            compare(plugin.lastCompletedJobId, "project-b-parent");
            compare(plugin.predictionStatus, "idle");
            plugin.currentProjectKey = "path:/test/project-a.qgs";
        }

        function test_cancelPreservesParentAndDraft() {
            plugin.changeObservation("A", "D", "connected");
            acceptRefinement();
            plugin.cancelLivePrediction();
            verify(request().url.endsWith("/child-job/cancel"));
            response(200, {message: "Cancelled by test"});
            compare(plugin.predictionStatus, "cancelled");
            compare(plugin.lastCompletedJobId, "parent-job");
            compare(plugin.observationDraft.length, 1);
            compare(plugin.activeJobId, "");
        }

        function test_serverFailedChildPreservesParentAndDraft() {
            plugin.changeObservation("A", "D", "connected");
            acceptRefinement();
            plugin.pollActiveJob();
            response(200, {status: "failed", message: "server test failure"});
            compare(plugin.predictionStatus, "failed");
            compare(plugin.lastCompletedJobId, "parent-job");
            compare(plugin.observationDraft.length, 1);
            compare(plugin.activeJobId, "");
        }

        function test_successfulEmptyResultCommitsInputAndObservationSnapshot() {
            plugin.changeObservation("A", "B", "disconnected");
            acceptRefinement();
            downloadResult({type: "FeatureCollection", features: []});
            compare(plugin.predictionStatus, "succeeded");
            compare(plugin.lastCompletedJobId, "child-job");
            compare(plugin.activeJobId, "");
            compare(plugin.resultCandidates.features.length, 2);
            compare(plugin.savedObservations[0].state, "disconnected");
            compare(plugin.observationDirty, false);
            compare(plugin.observationOverlayVisible, false);
            compare(plugin.predictionSummary.total, 0);
            compare(plugin.savedPredictionResultState().job_id, "child-job");
        }

        function test_mapInstallFailureDoesNotCommitChild() {
            plugin.changeObservation("A", "D", "connected");
            acceptRefinement();
            // qgisProject is null in this harness, so the real installation
            // method rejects this nonempty layer and keeps the old state.
            downloadResult({type: "FeatureCollection", features: [candidates.features[0]]});
            compare(plugin.predictionStatus, "fetching");
            compare(plugin.lastCompletedJobId, "parent-job");
            compare(plugin.observationDraft.length, 1);
            compare(plugin.savedObservations.length, 0);
            compare(plugin.activeJobId, "child-job");
            compare(plugin.activeJobCandidates.features.length, 2);
        }

        function test_pendingJobDetachAndRestore() {
            plugin.changeObservation("A", "D", "connected");
            acceptRefinement();
            plugin.detachActiveJob();
            compare(plugin.activeJobId, "");
            plugin.restorePendingJob();
            compare(plugin.activeJobId, "child-job");
            compare(plugin.activeJobObservations.length, 1);
            compare(plugin.activeJobParentId, "parent-job");
            compare(plugin.activeJobInputNodes.features.length, 4);
            plugin.clearActiveJob();
            plugin.restorePendingJob();
            compare(plugin.activeJobId, "", "Completed/cancelled child is removed from saved pending jobs");
        }

        function test_projectChangeAbortsRequestAndPreservesResumableJob() {
            plugin.changeObservation("A", "D", "connected");
            acceptRefinement();
            plugin.pollActiveJob();
            var oldRequest = request();
            iface.loadProjectTriggered("/test/project-b.qgs", "Project B");
            compare(oldRequest.aborted, true);
            compare(plugin.activeRequest, null);
            compare(plugin.activeJobId, "");
            compare(plugin.observationDraft.length, 0);
            plugin.currentProjectKey = "path:/test/project-b.qgs";
            plugin.projectName = "Project B";
            plugin.lastCompletedJobId = "project-b-parent";
            // Deliver an already queued event even after abort: request serial
            // and job/project guards must prevent stale completion adoption.
            oldRequest.status = 200;
            oldRequest.responseText = JSON.stringify({status: "succeeded"});
            oldRequest.onload();
            compare(plugin.lastCompletedJobId, "project-b-parent");
            plugin.restorePendingJob();
            compare(plugin.activeJobId, "", "Another project cannot resume this project's child");
            plugin.currentProjectKey = "path:/test/project-a.qgs";
            plugin.projectName = "Project A";
            plugin.restorePendingJob();
            compare(plugin.activeJobId, "child-job");
            compare(plugin.activeJobObservations[0].state, "connected");
        }

        function test_invalidOrIncompleteCandidateDownloadKeepsPendingParent() {
            plugin.changeObservation("A", "D", "connected");
            acceptRefinement();
            plugin.fetchLiveCandidates("child-job", "Pipes.geojson");
            response(200, {unexpected: "missing feature collection"});
            compare(plugin.activeJobId, "child-job");
            compare(plugin.lastCompletedJobId, "parent-job");
            compare(plugin.activeJobCandidates, null);
            compare(plugin.observationDraft.length, 1);
            compare(host.requests.length, 2, "Invalid candidates do not trigger a premature pipe download");
        }

        function test_parentBackendPinsRefinePollAndDownloadAfterRestore() {
            var parentBase = "https://parent-api.example.test/deeppipe/predapi";
            verify(parentBase !== plugin.defaultApiBaseUrl);
            plugin.resultApiBaseUrl = parentBase;
            plugin.changeObservation("A", "B", "disconnected");
            acceptRefinement();
            compare(plugin.activeJobApiBaseUrl, parentBase);
            compare(plugin.savedPredictionResultState().api_base_url, parentBase);
            plugin.detachActiveJob();
            compare(plugin.activeJobApiBaseUrl, "");
            plugin.restorePendingJob();
            compare(plugin.activeJobApiBaseUrl, parentBase);
            plugin.pollActiveJob();
            compare(request().url, parentBase + "/api/jobs/jobs/child-job/status");
            response(200, {status: "succeeded"});
            compare(request().url, parentBase + "/api/jobs/jobs/child-job/files");
            response(200, {files: ["Pipes.geojson", "Candidates.geojson"]});
            compare(request().url, parentBase + "/api/jobs/jobs/child-job/geojson/Candidates.geojson");
            response(200, candidates);
            compare(request().url, parentBase + "/api/jobs/jobs/child-job/geojson/Pipes.geojson");
            response(200, {type: "FeatureCollection", features: []});
            compare(plugin.predictionStatus, "succeeded");
            compare(plugin.resultApiBaseUrl, parentBase);
            compare(plugin.savedPredictionResultState().api_base_url, parentBase);
        }

        function test_pendingBackendMigration_data() {
            return [
                {tag: "legacy_without_pin", workflow: "classic", base: "", expected: "legacy"},
                {tag: "progressive_without_pin", workflow: "progressive", base: "", expected: "current"},
                {tag: "explicit_older_backend", workflow: "progressive", base: "https://saved-api.example.test/predapi", expected: "explicit"}
            ];
        }

        function test_pendingBackendMigration(data) {
            var expected = data.expected === "legacy" ? plugin.legacyApiBaseUrl
                    : data.expected === "current" ? plugin.defaultApiBaseUrl : data.base;
            plugin.activeJobId = "saved-job";
            plugin.activeJobProjectKey = plugin.currentProjectKey;
            plugin.activeJobProjectName = plugin.projectName;
            plugin.activeJobInputNodes = nodes;
            plugin.activeJobWorkflowType = data.workflow;
            plugin.activeJobApiBaseUrl = data.base;
            plugin.persistActiveJob();
            plugin.detachActiveJob();
            plugin.restorePendingJob();
            compare(plugin.activeJobApiBaseUrl, expected);
            plugin.pollActiveJob();
            compare(request().url, expected + "/api/jobs/jobs/saved-job/status");
            response(200, {status: "running"});
            plugin.cancelLivePrediction();
            compare(request().url, expected + "/api/jobs/jobs/saved-job/cancel");
            response(200, {message: "Cancelled by backend migration test"});
            compare(plugin.activeJobId, "");
        }

        function test_savedResultBackendMigration_data() {
            return test_pendingBackendMigration_data();
        }

        function test_savedResultBackendMigration(data) {
            var expected = data.expected === "legacy" ? plugin.legacyApiBaseUrl
                    : data.expected === "current" ? plugin.defaultApiBaseUrl : data.base;
            plugin.restoreObservationState({
                input_nodes: nodes, candidates: candidates,
                node_id_field: "node_id", workflow_type: data.workflow,
                api_base_url: data.base, prediction_config: plugin.resultPredictionConfig,
                observations: [], draft_observations: []
            });
            compare(plugin.resultApiBaseUrl, expected);
            plugin.persistObservationDraft();
            compare(plugin.savedPredictionResultState().api_base_url, expected);
        }

        function test_legacyPendingCompletionRetainsPotentialClassZero() {
            plugin.destroy();
            plugin = createTemporaryObject(capturedMapInstallFactory, host, {width: host.width, height: host.height});
            verify(plugin !== null);
            plugin.hasProject = true;
            plugin.projectPath = "/test/project-a.qgs";
            plugin.projectName = "Project A";
            plugin.currentProjectKey = "path:/test/project-a.qgs";
            plugin.activeJobId = "legacy-pending-job";
            plugin.activeJobProjectKey = plugin.currentProjectKey;
            plugin.activeJobProjectName = plugin.projectName;
            plugin.activeJobSelectedCount = 4;
            plugin.activeJobThreshold = 0.85;
            plugin.activeJobInputNodes = nodes;
            plugin.activeJobNodeIdField = "node_id";
            plugin.activeJobWorkflowType = "classic";
            // A pre-upgrade persisted job has no explicit backend pin.
            plugin.persistActiveJob();
            plugin.detachActiveJob();
            plugin.restorePendingJob();
            compare(plugin.activeJobApiBaseUrl, plugin.legacyApiBaseUrl);
            plugin.pollActiveJob();
            response(200, {status: "succeeded"});
            compare(request().url, plugin.legacyApiBaseUrl + "/api/jobs/jobs/legacy-pending-job/files");
            response(200, {files: ["Pipes.geojson"]});
            compare(request().url, plugin.legacyApiBaseUrl + "/api/jobs/jobs/legacy-pending-job/geojson/Pipes.geojson");
            response(200, {type: "FeatureCollection", features: [{
                type: "Feature", properties: {node_u: "A", node_v: "B", prob: 0.95, model_class: 1, class: 0},
                geometry: {type: "LineString", coordinates: [[-80, 35], [-79.999, 35]]}
            }]});
            compare(plugin.predictionStatus, "succeeded");
            compare(plugin.lastCompletedJobId, "legacy-pending-job");
            compare(plugin.activeJobId, "");
            compare(plugin.predictionSummary.total, 1);
            compare(plugin.predictionSummary.predicted, 0);
            compare(plugin.predictionSummary.potential, 1);
            verify(plugin.testInstalledCollection !== null, "Potential pipe reaches the map-install boundary");
            compare(plugin.testInstalledCollection.features[0].properties.workflow_type, "legacy");
            compare(plugin.testInstalledCollection.features[0].properties.deeppipe_outcome, "potential");
            compare(plugin.resultWorkflowType, "classic");
            compare(plugin.canUpdateObservations, false);
        }
    }
}
