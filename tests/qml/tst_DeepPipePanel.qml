import QtQuick
import QtQuick.Controls
import QtTest
import "../../plugin/deeppipe-mobile" as Plugin

// Real Qt Quick Controls test: the shipped panel is loaded unchanged.
// QField/QGIS map APIs are deliberately outside this panel-only harness.
Item {
    id: host
    width: 720
    height: 2600

    Component { id: panelFactory; Plugin.DeepPipePanel {} }
    Component { id: spyFactory; SignalSpy {} }

    TestCase {
        id: test
        name: "DeepPipePanel"
        when: windowShown
        property var panel

        function init() {
            host.width = 720;
            host.height = 2600;
            panel = createTemporaryObject(panelFactory, host, {
                width: host.width, height: host.height,
                hasProject: true, projectReady: true, setupState: "ready",
                inletLayerName: "Test inlets", selectedCount: 4,
                mockMode: false, predictionSettingsExpanded: true,
                completedJobId: "parent-job", canUpdateObservations: true,
                observationRows: [
                    { node_u: "A", node_v: "B", state: "unknown", selected: true, model_prob: 0.8 },
                    { node_u: "B", node_v: "C", state: "disconnected", selected: false, model_prob: 0.6 },
                    { node_u: "A", node_v: "D", state: "connected", selected: true, model_prob: 0.1 }
                ],
                observationDraft: [
                    { node_u: "B", node_v: "C", state: "disconnected" },
                    { node_u: "A", node_v: "D", state: "connected" }
                ],
                observationCount: 2, observationDirty: true
            });
            verify(panel !== null, "Shipped DeepPipePanel compiles and instantiates in Qt");
            var tab = findButton(panel, "Pipeline Prediction");
            verify(tab !== null);
            mouseClick(tab);
            wait(30);
        }

        function cleanup() {
            if (panel) panel.visible = false;
        }

        function findButton(item, text) {
            if (item.text === text && typeof item.clicked === "function") return item;
            var children = item.children || [];
            for (var i = 0; i < children.length; i++) {
                var match = findButton(children[i], text);
                if (match) return match;
            }
            return null;
        }

        function control(name) {
            var item = findChild(panel, name);
            verify(item !== null, name + " exists in real Panel");
            return item;
        }

        function spy(signal) {
            var result = createTemporaryObject(spyFactory, host, {target: panel, signalName: signal});
            verify(result.valid, signal + " is a real QML signal");
            return result;
        }

        function click(item) {
            verify(item.visible, "Control is visible");
            verify(item.enabled, "Control is enabled");
            mouseClick(item);
        }

        function openReview() {
            click(control("observationReviewButton"));
            var popup = control("observationReviewPopup");
            tryCompare(popup, "opened", true);
            return popup;
        }

        function test_progressiveDefaultsAndBounds() {
            compare(control("progressiveSectorSpinBox").value, 2);
            compare(control("progressiveSectorSpinBox").from, 1);
            compare(control("progressiveSectorSpinBox").to, 8);
            compare(control("progressiveKnnSpinBox").value, 12);
            compare(control("progressiveKnnSpinBox").to, 50);
            compare(control("progressiveDistanceSpinBox").value, 250);
            compare(control("progressiveDistanceSpinBox").to, 5000);
            compare(control("progressiveRoundsSpinBox").value, 3);
            compare(control("progressiveRoundsSpinBox").to, 10);
            compare(control("progressiveMsfSwitch").checked, true);
            verify(panel.predictionUsesDefaults());
            compare(findButton(panel, "Predict pipes from 4 inlets").enabled, true);
            panel.selectedCount = 3;
            compare(findButton(panel, "Predict pipes from 3 inlets").enabled, false);
        }

        function test_eachSettingEmitsProgressiveRequest_data() {
            return [
                { tag: "direction", name: "progressiveSectorSpinBox", field: "neighbors_per_sector", value: 3 },
                { tag: "knn", name: "progressiveKnnSpinBox", field: "knn_k", value: 13 },
                { tag: "feet", name: "progressiveDistanceSpinBox", field: "knn_max_distance_ft", value: 251 },
                { tag: "rounds", name: "progressiveRoundsSpinBox", field: "rounds", value: 4 }
            ];
        }

        function test_eachSettingEmitsProgressiveRequest(data) {
            var settings = spy("predictionSettingsRequested");
            var item = control(data.name);
            click(item.up.indicator);
            compare(item.value, data.value);
            compare(settings.count, 1);
            var request = settings.signalArguments[0][0];
            compare(request.workflow_type, "progressive");
            compare(request.model_type, "progressive_gnn");
            compare(request.progressive_config[data.field], data.value);
            compare(Object.keys(request).sort().join(","), "model_type,progressive_config,workflow_type");
        }

        function test_msfSwitchEmitsBoolean() {
            var settings = spy("predictionSettingsRequested");
            click(control("progressiveMsfSwitch"));
            compare(settings.count, 1);
            compare(settings.signalArguments[0][0].progressive_config.use_msf, false);
        }

        function test_restoreSavedSettings() {
            panel.predictionConfig = {workflow_type: "progressive", model_type: "progressive_gnn",
                progressive_config: {neighbors_per_sector: 4, knn_k: 20, knn_max_distance_ft: 375, rounds: 5, use_msf: false}};
            compare(control("progressiveSectorSpinBox").value, 4);
            compare(control("progressiveKnnSpinBox").value, 20);
            compare(control("progressiveDistanceSpinBox").value, 375);
            compare(control("progressiveRoundsSpinBox").value, 5);
            compare(control("progressiveMsfSwitch").checked, false);
            verify(!panel.predictionUsesDefaults());
            var reset = spy("resetPredictionSettingsRequested");
            click(findButton(panel, "Reset to DeepPipe defaults"));
            compare(reset.count, 1);
        }

        function test_observationChoices_data() {
            return [
                { tag: "confirm", key: Qt.Key_Home, steps: 1, state: "connected", index: 1 },
                { tag: "reject", key: Qt.Key_End, steps: 0, state: "disconnected", index: 2 },
                { tag: "remove", key: Qt.Key_Home, steps: 0, state: "unknown", index: 0 }
            ];
        }

        function test_observationChoices(data) {
            var changed = spy("observationRequested");
            var popup = openReview();
            var box = findChild(popup.contentItem, "observationStateBox");
            verify(box !== null);
            click(box);
            tryCompare(box.popup, "opened", true);
            keyClick(data.key);
            for (var n = 0; n < data.steps; n++) keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            compare(box.currentIndex, data.index);
            compare(changed.count, 1);
            compare(changed.signalArguments[0][0], "A");
            compare(changed.signalArguments[0][1], "B");
            compare(changed.signalArguments[0][2], data.state);
        }

        function test_observationActionSignals_data() {
            return [
                {tag: "add_missing_pair", name: "observationAddPairButton", signal: "addObservationPairRequested"},
                {tag: "undo", name: "observationUndoButton", signal: "undoObservationRequested"},
                {tag: "reset", name: "observationResetButton", signal: "resetObservationsRequested"},
                {tag: "clear", name: "observationClearButton", signal: "clearObservationsRequested"}
            ];
        }

        function test_observationActionSignals(data) {
            var requested = spy(data.signal);
            click(control(data.name));
            compare(requested.count, 1);
        }

        function test_updateClosesReviewAndEmits() {
            var updated = spy("updateObservationsRequested");
            var popup = openReview();
            // The modal review owns input while open; the runtime may also
            // invoke this public update action after a map observation.
            panel.updateObservedPrediction();
            tryCompare(popup, "opened", false);
            compare(updated.count, 1);
            click(control("observationUpdateButton"));
            compare(updated.count, 2);
        }

        function test_busyBlocksEditsAndShowsProgress() {
            panel.predictionStatus = "running";
            verify(panel.predictionBusy());
            compare(control("predictionBusyIndicator").running, true);
            compare(control("observationUpdateButton").enabled, false);
            compare(control("observationReviewButton").enabled, false);
            compare(control("observationAddPairButton").enabled, false);
            compare(control("progressiveKnnSpinBox").enabled, false);
            compare(control("progressiveMsfSwitch").enabled, false);
            panel.predictionStatus = "succeeded";
            compare(control("predictionBusyIndicator").running, false);
            compare(control("observationUpdateButton").enabled, true);
            panel.canUpdateObservations = false;
            compare(control("observationUpdateButton").enabled, false);
        }

        function test_mobileWidthCompilesAndPopupFits() {
            host.width = 390;
            host.height = 780;
            panel.width = host.width;
            panel.height = host.height;
            // Open through the same actual QML action, independent of scroll.
            control("observationReviewButton").clicked();
            var popup = control("observationReviewPopup");
            tryCompare(popup, "opened", true);
            verify(popup.width <= host.width);
            verify(popup.height <= host.height);
            verify(popup.x >= 0);
            verify(popup.y >= 0);
        }
    }
}
