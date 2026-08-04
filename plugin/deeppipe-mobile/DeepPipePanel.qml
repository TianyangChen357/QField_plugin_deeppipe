import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: panel

    property bool hasProject: false
    property bool projectReady: false
    property bool assessmentReady: false
    property string projectName: "No project"
    property string setupState: "no_project"
    property string setupMessage: "Open a QField project to begin."
    property var layerNames: []
    property var layerIds: []
    property string inletLayerId: ""
    property string inletLayerName: ""
    property var fieldNames: []
    property string nodeIdField: ""
    property bool mappingConfirmed: false
    property int selectedCount: 0
    property bool inletSelectionActive: false
    property string predictionStatus: "idle"
    property string predictionMessage: ""
    property var predictionSummary: null
    property string predictionResultLayer: ""
    property string predictionExportPath: ""
    property real maxSearchRadius: 500
    property real confidenceThreshold: 0.85
    property string assessmentLocationLabel: "No location selected"
    property string assessmentStatus: "idle"
    property string assessmentMessage: "Choose a map or GNSS location."
    property var assessmentResult: null
    property real assessmentNominalDiameter: 16
    property int assessmentGauge: 16
    property string assessmentMaterialId: "rcp"
    property int assessmentMinimumYears: 0
    property bool mockMode: true
    property string apiBaseUrl: ""
    property string apiConnectionStatus: "unknown"
    property string apiConnectionMessage: "Not checked"
    property string passApiBaseUrl: ""
    property string remoteCogUrl: ""
    property string remoteCogLayerName: "DeepPipe Remote COG"
    property string rasterStatus: "idle"
    property string rasterMessage: "No PyPASS or COG raster has been added by the plugin."
    property var rasterLayerNames: []
    property string activeJobId: ""
    property string pluginVersion: "0.4.0"

    signal closeRequested()
    signal refreshProjectRequested()
    signal inletLayerRequested(string layerId)
    signal nodeIdFieldRequested(string fieldName)
    signal confirmProjectMappingRequested()
    signal selectInletsRequested()
    signal finishSelectionRequested()
    signal clearSelectionRequested()
    signal predictionParametersRequested(real maximumDistance, real threshold)
    signal runPredictionRequested()
    signal cancelPredictionRequested()
    signal removePredictionLayerRequested()
    signal exportPredictionRequested()
    signal sharePredictionExportRequested()
    signal pickAssessmentLocationRequested()
    signal useGnssRequested()
    signal assessmentInputsRequested(real nominalDiameter, int gauge, string materialId, int minimumYears)
    signal runAssessmentRequested()
    signal addPassVariableRasterRequested(string variableId, string name)
    signal addPassServiceLifeRasterRequested()
    signal addRemoteCogRequested()
    signal removeRasterLayersRequested()
    signal apiBaseUrlRequested(string value)
    signal passApiBaseUrlRequested(string value)
    signal remoteCogConfigurationRequested(string url, string layerName)
    signal apiModeRequested(bool enabled)
    signal testApiRequested()

    readonly property color ink: "#17332E"
    readonly property color mutedInk: "#61736F"
    readonly property color surface: "#FFFFFF"
    readonly property color canvas: "#F3F6F5"
    readonly property color primary: "#087565"
    readonly property color primaryDark: "#075B50"
    readonly property color accent: "#F2B84B"
    readonly property color divider: "#DDE5E2"
    readonly property color success: "#157A55"
    readonly property color warning: "#A56600"
    readonly property color danger: "#B43B32"
    readonly property var passMaterialIds: ["rcp", "cast_iron", "plastic", "galvanized", "aluminized_csp", "aluminum", "steel"]
    readonly property var passMaterialNames: ["RCP", "Cast Iron", "HDPE / PP / PVC", "Galvanized", "Aluminized CSP", "Aluminum", "Steel"]
    readonly property var gaugeValues: [8, 10, 12, 14, 16, 18]

    function predictionStatusColor() {
        if (predictionStatus === "succeeded") return success;
        if (predictionStatus === "failed") return danger;
        if (predictionStatus === "cancelled") return mutedInk;
        if (predictionBusy()) return warning;
        return mutedInk;
    }

    function predictionBusy() {
        return ["submitting", "queued", "running", "fetching", "cancelling", "cancel_requested"].indexOf(predictionStatus) >= 0;
    }

    function predictionStatusLabel() {
        if (predictionStatus === "idle") return "Ready";
        if (predictionStatus === "succeeded") return mockMode ? "Preview ready" : "Prediction ready";
        if (predictionStatus === "failed") return "Needs attention";
        if (predictionStatus === "fetching") return "Loading result";
        if (predictionStatus === "submitting") return "Submitting";
        if (predictionStatus === "cancelling") return "Cancelling";
        if (predictionStatus === "cancelled") return "Cancelled";
        return predictionStatus.charAt(0).toUpperCase() + predictionStatus.slice(1);
    }

    function apiStatusColor() {
        if (apiConnectionStatus === "ok") return success;
        if (apiConnectionStatus === "failed") return danger;
        if (apiConnectionStatus === "checking") return warning;
        return mutedInk;
    }

    function setupStatusTitle() {
        if (projectReady) return "DeepPipe project ready";
        if (setupState === "no_project") return "No project open";
        if (setupState === "no_point_layers") return "Inlet point layer required";
        if (setupState === "invalid_field") return "Project setup needs attention";
        return "Finish project setup";
    }

    function assessmentBusy() {
        return assessmentStatus === "running";
    }

    function formattedSoilValue(value, suffix, decimals) {
        if (value === null || value === undefined || value === "" || !Number.isFinite(Number(value))) return "Unavailable";
        var number = Number(value);
        var text = decimals === undefined ? String(number) : number.toFixed(decimals);
        return text + String(suffix || "");
    }

    function formattedYears(value) {
        if (value === null || value === undefined || value === "" || !Number.isFinite(Number(value))) return "Unavailable";
        return Number(value).toFixed(1) + " yr";
    }

    Rectangle {
        anchors.fill: parent
        color: panel.canvas

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: panel.surface
                border.color: panel.divider
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 10
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 12
                        color: panel.primary

                        Text {
                            anchors.centerIn: parent
                            text: "DP"
                            color: "white"
                            font.pixelSize: 15
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: "DeepPipe Mobile"
                            color: panel.ink
                            font.pixelSize: 20
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: panel.projectName
                            color: panel.mutedInk
                            font.pixelSize: 12
                            elide: Text.ElideMiddle
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: panel.mockMode ? 58 : 82
                        Layout.preferredHeight: 28
                        radius: 14
                        color: panel.mockMode ? "#FFF3D9" : "#DDF2EA"

                        Text {
                            anchors.centerIn: parent
                            text: panel.mockMode ? "MOCK" : "PRED LIVE"
                            color: panel.mockMode ? panel.warning : panel.success
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    ToolButton {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        text: "×"
                        font.pixelSize: 28
                        Accessible.name: "Close DeepPipe"
                        onClicked: panel.closeRequested()
                    }
                }
            }

            TabBar {
                id: tabBar
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                background: Rectangle { color: panel.surface }

                TabButton {
                    text: "Prediction"
                    font.bold: checked
                    height: 52
                }
                TabButton {
                    text: "Assessment"
                    font.bold: checked
                    height: 52
                }
                TabButton {
                    text: "Setup"
                    font.bold: checked
                    height: 52
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabBar.currentIndex

                ScrollView {
                    id: predictionScroll
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: predictionScroll.availableWidth
                        spacing: 14

                        Item { Layout.preferredHeight: 2 }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: projectStatusColumn.implicitHeight + 28
                            radius: 14
                            color: panel.projectReady ? "#E4F3ED" : "#FFF6E6"
                            border.color: panel.projectReady ? "#B7DBCD" : "#E7C98C"

                            ColumnLayout {
                                id: projectStatusColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: panel.setupStatusTitle()
                                        color: panel.projectReady ? panel.success : panel.warning
                                        font.pixelSize: 15
                                        font.bold: true
                                    }
                                    Button {
                                        text: panel.projectReady ? "Refresh" : "Setup"
                                        flat: true
                                        implicitHeight: 44
                                        onClicked: {
                                            if (panel.projectReady) panel.refreshProjectRequested();
                                            else tabBar.currentIndex = 2;
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.setupMessage
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: sourceColumn.implicitHeight + 28
                            radius: 14
                            color: panel.surface
                            border.color: panel.divider

                            ColumnLayout {
                                id: sourceColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 10

                                Text {
                                    text: "1  Choose the field inlet layer"
                                    color: panel.ink
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Points saved locally in QField can be used immediately; they do not need to be exported as a list first."
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                ComboBox {
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    enabled: panel.hasProject && panel.layerNames.length > 0 && !panel.predictionBusy()
                                    model: panel.layerNames
                                    currentIndex: panel.layerIds.indexOf(panel.inletLayerId)
                                    Accessible.name: "Inlet layer"
                                    onActivated: panel.inletLayerRequested(panel.layerIds[currentIndex])
                                }
                                Text {
                                    text: "ID field: " + (panel.nodeIdField || "Not configured") +
                                          (panel.nodeIdField.toLowerCase().indexOf("uuid") >= 0 ? " · UUID" : "")
                                    color: panel.mutedInk
                                    font.pixelSize: 12
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: selectionColumn.implicitHeight + 28
                            radius: 14
                            color: panel.surface
                            border.color: panel.inletSelectionActive ? panel.primary : panel.divider
                            border.width: panel.inletSelectionActive ? 2 : 1

                            ColumnLayout {
                                id: selectionColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: "2  Select inlets on the map"
                                        color: panel.ink
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: countText.implicitWidth + 22
                                        Layout.preferredHeight: 30
                                        radius: 15
                                        color: panel.selectedCount >= 3 ? "#DDF2EA" : "#EEF1F0"
                                        Text {
                                            id: countText
                                            anchors.centerIn: parent
                                            text: panel.selectedCount + " selected"
                                            color: panel.selectedCount >= 3 ? panel.success : panel.mutedInk
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.inletSelectionActive
                                          ? "Selection mode is active. Use Tap, Box, or Visible on the map, then press Done."
                                          : "Select individual inlets, drag a box around many points, or add every inlet currently visible. A minimum of three is required."
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 54
                                    text: panel.inletSelectionActive ? "Return to map selection" : "Select inlets on map"
                                    enabled: panel.projectReady && panel.inletLayerName.length > 0 && !panel.predictionBusy()
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: panel.selectInletsRequested()
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 48
                                    text: "Clear selected inlets"
                                    enabled: panel.selectedCount > 0 && !panel.predictionBusy()
                                    flat: true
                                    onClicked: panel.clearSelectionRequested()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: parametersColumn.implicitHeight + 28
                            radius: 14
                            color: panel.surface
                            border.color: panel.divider

                            ColumnLayout {
                                id: parametersColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 10

                                Text {
                                    text: "3  Prediction settings"
                                    color: panel.ink
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Maximum connection distance"
                                        color: panel.ink
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        text: Math.round(distanceSlider.value) + " ft"
                                        color: panel.primary
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }
                                Slider {
                                    id: distanceSlider
                                    Layout.fillWidth: true
                                    from: 100
                                    to: 1500
                                    stepSize: 50
                                    value: panel.maxSearchRadius
                                    enabled: !panel.predictionBusy()
                                    implicitHeight: 44
                                    onMoved: panel.predictionParametersRequested(value, thresholdSlider.value)
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Confidence threshold"
                                        color: panel.ink
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        text: thresholdSlider.value.toFixed(2)
                                        color: panel.primary
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }
                                Slider {
                                    id: thresholdSlider
                                    Layout.fillWidth: true
                                    from: 0.51
                                    to: 0.99
                                    stepSize: 0.01
                                    value: panel.confidenceThreshold
                                    enabled: !panel.predictionBusy()
                                    implicitHeight: 44
                                    onMoved: panel.predictionParametersRequested(distanceSlider.value, value)
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Recommended preset: GNN · 12 neighbors · MST enabled · 0.50 probability / 0.50 length weighting"
                                    color: panel.mutedInk
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: !panel.mockMode
                                    text: "Live test output is experimental. Do not treat predicted pipes as verified infrastructure."
                                    color: panel.warning
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 56
                                    text: panel.selectedCount > 0
                                          ? (panel.mockMode ? "Preview pipes from " : "Predict pipes from ") + panel.selectedCount + " inlets"
                                          : "Select inlets to continue"
                                    enabled: panel.projectReady && panel.selectedCount >= 3 && !panel.predictionBusy()
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: panel.runPredictionRequested()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: resultColumn.implicitHeight + 28
                            radius: 14
                            visible: panel.predictionStatus !== "idle" || panel.predictionSummary !== null
                            color: panel.surface
                            border.color: panel.divider

                            ColumnLayout {
                                id: resultColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Rectangle {
                                        Layout.preferredWidth: 10
                                        Layout.preferredHeight: 10
                                        radius: 5
                                        color: panel.predictionStatusColor()
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: panel.predictionStatusLabel()
                                        color: panel.ink
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.predictionMessage
                                    visible: text.length > 0
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.activeJobId.length > 0 ? "Job ID: " + panel.activeJobId : ""
                                    visible: text.length > 0
                                    color: panel.mutedInk
                                    font.pixelSize: 12
                                    elide: Text.ElideMiddle
                                }
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 4
                                    visible: panel.predictionSummary !== null
                                    columnSpacing: 8
                                    rowSpacing: 4

                                    Text { text: "Selected"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: "Predicted"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: "Potential"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: "Unknown"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: panel.predictionSummary ? panel.predictionSummary.selectedInlets : "—"; color: panel.ink; font.pixelSize: 20; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: panel.predictionSummary ? panel.predictionSummary.predicted : "—"; color: panel.success; font.pixelSize: 20; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text {
                                        text: panel.predictionSummary && panel.predictionSummary.potential !== null && panel.predictionSummary.potential !== undefined
                                              ? panel.predictionSummary.potential : "—"
                                        color: panel.warning
                                        font.pixelSize: 20
                                        font.bold: true
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Text {
                                        text: panel.predictionSummary && panel.predictionSummary.unknown !== undefined
                                              ? panel.predictionSummary.unknown : "—"
                                        color: panel.mutedInk
                                        font.pixelSize: 20
                                        font.bold: true
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: !panel.mockMode && panel.predictionSummary !== null &&
                                             (panel.predictionSummary.potential === null || panel.predictionSummary.potential === undefined)
                                    text: "The API returns only pipes at or above the selected threshold; the potential-pipe count is not available."
                                    color: panel.mutedInk
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: panel.predictionSummary !== null &&
                                             panel.predictionSummary.potential !== null &&
                                             panel.predictionSummary.potential > 0
                                    text: "Predicted pipes use the normal result-layer opacity; potential pipes are placed in a separate semi-transparent layer."
                                    color: panel.mutedInk
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.predictionResultLayer.length > 0
                                          ? "Map layer: " + panel.predictionResultLayer
                                          : ""
                                    visible: text.length > 0
                                    color: panel.mutedInk
                                    font.pixelSize: 12
                                    elide: Text.ElideMiddle
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: "Save combined result as GeoJSON"
                                    visible: panel.predictionResultLayer.length > 0
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: panel.exportPredictionRequested()
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.predictionExportPath.length > 0 ? "Saved: " + panel.predictionExportPath : ""
                                    visible: text.length > 0
                                    color: panel.success
                                    font.pixelSize: 11
                                    wrapMode: Text.WrapAnywhere
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 46
                                    text: "Share exported GeoJSON"
                                    visible: panel.predictionExportPath.length > 0
                                    flat: true
                                    onClicked: panel.sharePredictionExportRequested()
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 48
                                    text: panel.mockMode ? "Remove preview result layer" : "Remove prediction result layer"
                                    visible: panel.predictionResultLayer.length > 0
                                    flat: true
                                    onClicked: panel.removePredictionLayerRequested()
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 48
                                    text: "Cancel active prediction"
                                    visible: !panel.mockMode && panel.activeJobId.length > 0 && panel.predictionStatus !== "cancelling"
                                    enabled: panel.predictionBusy()
                                    palette.button: panel.danger
                                    palette.buttonText: "white"
                                    onClicked: panel.cancelPredictionRequested()
                                }
                            }
                        }

                        Item { Layout.preferredHeight: 18 }
                    }
                }

                ScrollView {
                    id: assessmentScroll
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: assessmentScroll.availableWidth
                        spacing: 14

                        Item { Layout.preferredHeight: 2 }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: assessmentIntro.implicitHeight + 28
                            radius: 14
                            color: "#EAF2F8"
                            border.color: "#C9DCE9"

                            ColumnLayout {
                                id: assessmentIntro
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 6
                                Text {
                                    text: "Pipe service-life assessment"
                                    color: panel.ink
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Choose a map location or current GNSS position, then query the live PyPASS service for soil properties and service-life comparison. Results are estimates for review, not an automatic material recommendation."
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: locationColumn.implicitHeight + 28
                            radius: 14
                            color: panel.surface
                            border.color: panel.divider

                            ColumnLayout {
                                id: locationColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 10
                                Text {
                                    text: "1  Assessment location"
                                    color: panel.ink
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.assessmentLocationLabel
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 54
                                    text: "Pick a point on the map"
                                    enabled: panel.assessmentReady && !panel.assessmentBusy()
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: panel.pickAssessmentLocationRequested()
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: "Use current GNSS location"
                                    enabled: panel.assessmentReady && !panel.assessmentBusy()
                                    onClicked: panel.useGnssRequested()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: assessActionColumn.implicitHeight + 28
                            radius: 14
                            color: panel.surface
                            border.color: panel.divider

                            ColumnLayout {
                                id: assessActionColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 10
                                Text {
                                    text: "2  Compare service-life estimates"
                                    color: panel.ink
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Diameter affects the cast-iron estimate. Gauge selects which gauge-based estimates are shown."
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                Text { text: "Cast-iron nominal diameter (in)"; color: panel.mutedInk; font.pixelSize: 12 }
                                TextField {
                                    id: diameterField
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: String(panel.assessmentNominalDiameter)
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                    enabled: !panel.assessmentBusy()
                                    onEditingFinished: panel.assessmentInputsRequested(
                                                           Number(text),
                                                           panel.assessmentGauge,
                                                           panel.assessmentMaterialId,
                                                           panel.assessmentMinimumYears)
                                }
                                Text { text: "Gauge for corrugated materials"; color: panel.mutedInk; font.pixelSize: 12 }
                                ComboBox {
                                    id: assessmentGaugeBox
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    model: panel.gaugeValues
                                    currentIndex: panel.gaugeValues.indexOf(panel.assessmentGauge)
                                    enabled: !panel.assessmentBusy()
                                    onActivated: panel.assessmentInputsRequested(
                                                     Number(diameterField.text),
                                                     Number(currentText),
                                                     panel.assessmentMaterialId,
                                                     panel.assessmentMinimumYears)
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.assessmentMessage
                                    color: panel.assessmentStatus === "failed" ? panel.danger : panel.mutedInk
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 56
                                    text: panel.assessmentBusy() ? "Querying PyPASS…" : "Run live service-life assessment"
                                    enabled: panel.assessmentReady && panel.assessmentLocationLabel !== "No location selected" &&
                                             !panel.assessmentBusy() && !panel.predictionBusy() && panel.rasterStatus !== "loading" &&
                                             Number(diameterField.text) > 0
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: {
                                        panel.assessmentInputsRequested(
                                                    Number(diameterField.text),
                                                    panel.assessmentGauge,
                                                    panel.assessmentMaterialId,
                                                    panel.assessmentMinimumYears);
                                        panel.runAssessmentRequested();
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: assessmentResultsColumn.implicitHeight + 28
                            radius: 14
                            visible: panel.assessmentResult !== null
                            color: panel.surface
                            border.color: panel.divider

                            ColumnLayout {
                                id: assessmentResultsColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Live PyPASS assessment"
                                        color: panel.ink
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 58
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: "#DDF2EA"
                                        Text { anchors.centerIn: parent; text: "LIVE"; color: panel.success; font.pixelSize: 11; font.bold: true }
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 3
                                    columnSpacing: 8
                                    Text { text: "pH"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: "Resistivity"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: "Chloride"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: panel.assessmentResult ? panel.formattedSoilValue(panel.assessmentResult.soil.ph, "", 1) : "—"; color: panel.ink; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                                    Text { text: panel.assessmentResult ? panel.formattedSoilValue(panel.assessmentResult.soil.resistivity_ohm_cm, " Ω·cm") : "—"; color: panel.ink; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                                    Text { text: panel.assessmentResult && panel.assessmentResult.soil.chloride !== null ? panel.assessmentResult.soil.chloride : "Unavailable"; color: panel.ink; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                                }

                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: panel.divider }

                                Repeater {
                                    model: panel.assessmentResult ? panel.assessmentResult.estimates : []
                                    delegate: RowLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumHeight: 40
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name + (modelData.gauge ? " · gauge " + modelData.gauge : "")
                                            color: panel.ink
                                            font.pixelSize: 13
                                        }
                                        Text {
                                            text: panel.formattedYears(modelData.years)
                                            color: panel.primaryDark
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                    }
                                }

                                Repeater {
                                    model: panel.assessmentResult && panel.assessmentResult.warnings
                                           ? panel.assessmentResult.warnings : []
                                    delegate: Text {
                                        Layout.fillWidth: true
                                        text: "Coverage note: " + modelData
                                        color: panel.warning
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "PyPASS compares estimated service life across materials and gauges. It does not select or recommend a material; engineering, cost, and field criteria still require review."
                                    color: panel.warning
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: rasterColumn.implicitHeight + 28
                            radius: 14
                            color: panel.surface
                            border.color: panel.divider

                            ColumnLayout {
                                id: rasterColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 10

                                Text {
                                    text: "3  Review hosted raster layers"
                                    color: panel.ink
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Add the live PyPASS soil or service-life tiles to the QField map. You can also provide a direct public HTTPS COG/GeoTIFF URL; no default raw COG URL is embedded in the plugin."
                                    color: panel.mutedInk
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Button {
                                        Layout.fillWidth: true
                                        implicitHeight: 48
                                        text: "pH"
                                        enabled: !panel.predictionBusy() && !panel.assessmentBusy() && panel.rasterStatus !== "loading"
                                        onClicked: panel.addPassVariableRasterRequested("ph", "pH")
                                    }
                                    Button {
                                        Layout.fillWidth: true
                                        implicitHeight: 48
                                        text: "Resistivity"
                                        enabled: !panel.predictionBusy() && !panel.assessmentBusy() && panel.rasterStatus !== "loading"
                                        onClicked: panel.addPassVariableRasterRequested("resistivity", "Resistivity")
                                    }
                                    Button {
                                        Layout.fillWidth: true
                                        implicitHeight: 48
                                        text: "Chloride"
                                        enabled: !panel.predictionBusy() && !panel.assessmentBusy() && panel.rasterStatus !== "loading"
                                        onClicked: panel.addPassVariableRasterRequested("chloride", "Chloride")
                                    }
                                }

                                Text { text: "Service-life material"; color: panel.mutedInk; font.pixelSize: 12 }
                                ComboBox {
                                    id: rasterMaterialBox
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    model: panel.passMaterialNames
                                    currentIndex: Math.max(0, panel.passMaterialIds.indexOf(panel.assessmentMaterialId))
                                    onActivated: panel.assessmentInputsRequested(
                                                     Number(diameterField.text),
                                                     panel.assessmentGauge,
                                                     panel.passMaterialIds[currentIndex],
                                                     panel.assessmentMinimumYears)
                                }
                                Text { text: "Minimum service life (years)"; color: panel.mutedInk; font.pixelSize: 12 }
                                TextField {
                                    id: minimumYearsField
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: String(panel.assessmentMinimumYears)
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    onEditingFinished: panel.assessmentInputsRequested(
                                                           Number(diameterField.text),
                                                           panel.assessmentGauge,
                                                           panel.assessmentMaterialId,
                                                           Math.max(0, Number(text) || 0))
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: "Add service-life raster"
                                    enabled: !panel.predictionBusy() && !panel.assessmentBusy() && panel.rasterStatus !== "loading"
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: {
                                        panel.assessmentInputsRequested(
                                                    Number(diameterField.text),
                                                    panel.assessmentGauge,
                                                    panel.assessmentMaterialId,
                                                    Math.max(0, Number(minimumYearsField.text) || 0));
                                        panel.addPassServiceLifeRasterRequested();
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: panel.divider }
                                Text { text: "Direct COG/GeoTIFF URL"; color: panel.mutedInk; font.pixelSize: 12 }
                                TextField {
                                    id: cogUrlField
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: panel.remoteCogUrl
                                    placeholderText: "https://host/path/layer.tif"
                                    inputMethodHints: Qt.ImhUrlCharactersOnly
                                    onEditingFinished: panel.remoteCogConfigurationRequested(text.trim(), cogNameField.text.trim())
                                }
                                TextField {
                                    id: cogNameField
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: panel.remoteCogLayerName
                                    placeholderText: "Remote COG layer name"
                                    onEditingFinished: panel.remoteCogConfigurationRequested(cogUrlField.text.trim(), text.trim())
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: "Add remote COG to map"
                                    enabled: !panel.predictionBusy() && !panel.assessmentBusy() && panel.rasterStatus !== "loading"
                                    onClicked: {
                                        panel.remoteCogConfigurationRequested(cogUrlField.text.trim(), cogNameField.text.trim());
                                        panel.addRemoteCogRequested();
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.rasterMessage
                                    color: panel.rasterStatus === "failed" ? panel.danger : panel.mutedInk
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.rasterLayerNames.length > 0
                                          ? "Plugin raster layers: " + panel.rasterLayerNames.join(", ") : ""
                                    visible: text.length > 0
                                    color: panel.mutedInk
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 46
                                    text: "Remove plugin raster layers"
                                    visible: panel.rasterLayerNames.length > 0
                                    flat: true
                                    onClicked: panel.removeRasterLayersRequested()
                                }
                            }
                        }

                        Item { Layout.preferredHeight: 18 }
                    }
                }

                ScrollView {
                    id: setupScroll
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: setupScroll.availableWidth
                        spacing: 14

                        Item { Layout.preferredHeight: 2 }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: schemaColumn.implicitHeight + 28
                            radius: 14
                            color: panel.surface
                            border.color: panel.divider

                            ColumnLayout {
                                id: schemaColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 10
                                Text {
                                    text: "Project mapping"
                                    color: panel.ink
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Choose the inlet point layer and its stable ID field. The mapping is saved for this project on this device; optional DeepPipe project properties can still prefill it for a team."
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: setupHint.implicitHeight + 20
                                    radius: 10
                                    color: panel.projectReady ? "#E4F3ED" : "#FFF6E6"
                                    border.color: panel.projectReady ? "#B7DBCD" : "#E7C98C"
                                    Text {
                                        id: setupHint
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 10
                                        text: panel.setupMessage
                                        color: panel.projectReady ? panel.success : panel.warning
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                    }
                                }
                                Text { text: "Inlet layer"; color: panel.mutedInk; font.pixelSize: 12 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    enabled: panel.hasProject && panel.layerNames.length > 0 && !panel.predictionBusy()
                                    model: panel.layerNames
                                    currentIndex: panel.layerIds.indexOf(panel.inletLayerId)
                                    displayText: currentIndex >= 0 ? currentText : "Choose a point layer"
                                    onActivated: panel.inletLayerRequested(panel.layerIds[currentIndex])
                                }
                                Text { text: "Unique inlet ID field"; color: panel.mutedInk; font.pixelSize: 12 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    enabled: panel.inletLayerId.length > 0 && panel.fieldNames.length > 0 && !panel.predictionBusy()
                                    model: panel.fieldNames
                                    currentIndex: panel.fieldNames.indexOf(panel.nodeIdField)
                                    displayText: currentIndex >= 0 ? currentText : "Choose an ID field"
                                    onActivated: panel.nodeIdFieldRequested(currentText)
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "For multiple users and offline collection, use a text UUID field with the QGIS default expression uuid('WithoutBraces'). The value must be generated once when the inlet is created and remain unchanged."
                                    color: panel.mutedInk
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 54
                                    text: panel.projectReady ? "Project setup saved" : "Use this project setup"
                                    enabled: panel.hasProject && panel.inletLayerId.length > 0 &&
                                             panel.nodeIdField.length > 0 &&
                                             panel.fieldNames.indexOf(panel.nodeIdField) >= 0 &&
                                             !panel.predictionBusy()
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: panel.confirmProjectMappingRequested()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: apiColumn.implicitHeight + 28
                            radius: 14
                            color: panel.surface
                            border.color: panel.divider

                            ColumnLayout {
                                id: apiColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 10
                                Text {
                                    text: "API connection"
                                    color: panel.ink
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text { text: "Use live Prediction API"; color: panel.ink; font.pixelSize: 14; font.bold: true }
                                        Text { text: "PyPASS assessment uses its own live endpoint"; color: panel.mutedInk; font.pixelSize: 11 }
                                    }
                                    Switch {
                                        checked: !panel.mockMode
                                        enabled: panel.activeJobId.length === 0 && !panel.predictionBusy()
                                        Accessible.name: "Use live DeepPipe prediction API"
                                        onClicked: panel.apiModeRequested(checked)
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 42
                                    radius: 9
                                    color: panel.mockMode ? "#FFF3D9" : "#DDF2EA"
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        Text { text: "Prediction transport"; color: panel.mockMode ? panel.warning : panel.success; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
                                        Text { text: panel.mockMode ? "Mock" : "Live API"; color: panel.mockMode ? panel.warning : panel.success; font.pixelSize: 13 }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.mockMode
                                          ? "Mock mode keeps every operation on the phone and generates a deterministic preview."
                                          : "Selected inlets are transformed to EPSG:4326 and sent as GeoJSON. The returned task ID is saved so polling can resume after the project is reopened."
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                TextField {
                                    id: apiField
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: panel.apiBaseUrl
                                    placeholderText: "https://api.example.org"
                                    inputMethodHints: Qt.ImhUrlCharactersOnly
                                    enabled: panel.activeJobId.length === 0 && !panel.predictionBusy()
                                    onEditingFinished: panel.apiBaseUrlRequested(text.trim())
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Rectangle {
                                        Layout.preferredWidth: 10
                                        Layout.preferredHeight: 10
                                        radius: 5
                                        color: panel.apiStatusColor()
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: panel.apiConnectionMessage
                                        color: panel.mutedInk
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                    }
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 48
                                    text: panel.apiConnectionStatus === "checking" ? "Checking API…" : "Test API connection"
                                    enabled: panel.apiConnectionStatus !== "checking" && panel.activeJobId.length === 0 && !panel.predictionBusy()
                                    onClicked: panel.testApiRequested()
                                }
                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: panel.divider }
                                Text { text: "PyPASS API origin"; color: panel.ink; font.pixelSize: 14; font.bold: true }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Used for live point assessment and hosted raster catalogs. Keep it separate from the /predapi Prediction base."
                                    color: panel.mutedInk
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                                TextField {
                                    id: passApiField
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: panel.passApiBaseUrl
                                    placeholderText: "https://host.example.org"
                                    inputMethodHints: Qt.ImhUrlCharactersOnly
                                    onEditingFinished: panel.passApiBaseUrlRequested(text.trim())
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: !panel.mockMode
                                    text: "Test endpoint notice: the current API advertises no authentication. Do not submit sensitive field data. Live output is experimental and requires engineering review."
                                    color: panel.warning
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: 90
                            radius: 14
                            color: "#F7F9F8"
                            border.color: panel.divider
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                Text { text: "DeepPipe Mobile " + panel.pluginVersion; color: panel.ink; font.pixelSize: 14; font.bold: true }
                                Text { Layout.fillWidth: true; text: "Map inlet selection · resumable Prediction jobs · GeoJSON export · live PyPASS assessment · hosted raster review"; color: panel.mutedInk; font.pixelSize: 12; wrapMode: Text.WordWrap }
                            }
                        }

                        Item { Layout.preferredHeight: 18 }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (!panel.projectReady) tabBar.currentIndex = 2;
    }

    onSetupStateChanged: {
        if (panel.setupState !== "ready") tabBar.currentIndex = 2;
    }
}
