import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: panel

    property bool projectEnabled: false
    property string projectName: "No project"
    property var layerNames: []
    property string inletLayerName: ""
    property string nodeIdField: "node_id"
    property int selectedCount: 0
    property bool inletSelectionActive: false
    property string predictionStatus: "idle"
    property string predictionMessage: ""
    property var predictionSummary: null
    property string predictionResultLayer: ""
    property real maxSearchRadius: 500
    property real confidenceThreshold: 0.85
    property string assessmentLocationLabel: "No location selected"
    property string assessmentStatus: "idle"
    property var assessmentResult: null
    property bool mockMode: true
    property string apiBaseUrl: ""
    property string apiConnectionStatus: "unknown"
    property string apiConnectionMessage: "Not checked"
    property string activeJobId: ""
    property string pluginVersion: "0.2.0"

    signal closeRequested()
    signal refreshProjectRequested()
    signal inletLayerRequested(string layerName)
    signal nodeIdFieldRequested(string fieldName)
    signal selectInletsRequested()
    signal finishSelectionRequested()
    signal clearSelectionRequested()
    signal predictionParametersRequested(real maximumDistance, real threshold)
    signal runPredictionRequested()
    signal cancelPredictionRequested()
    signal removePredictionLayerRequested()
    signal pickAssessmentLocationRequested()
    signal useGnssRequested()
    signal runAssessmentRequested()
    signal apiBaseUrlRequested(string value)
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
                            color: panel.projectEnabled ? "#E4F3ED" : "#FFF0ED"
                            border.color: panel.projectEnabled ? "#B7DBCD" : "#EDC2BB"

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
                                        text: panel.projectEnabled ? "DeepPipe project detected" : "Project setup required"
                                        color: panel.projectEnabled ? panel.success : panel.danger
                                        font.pixelSize: 15
                                        font.bold: true
                                    }
                                    Button {
                                        text: "Refresh"
                                        flat: true
                                        implicitHeight: 44
                                        onClicked: panel.refreshProjectRequested()
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.projectEnabled
                                          ? "The inlet layer and field mapping are loaded from this QField project."
                                          : "Open a DeepPipe-compatible project or configure the required project properties."
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
                                    enabled: panel.projectEnabled && panel.layerNames.length > 0 && !panel.predictionBusy()
                                    model: panel.layerNames
                                    currentIndex: Math.max(0, panel.layerNames.indexOf(panel.inletLayerName))
                                    Accessible.name: "Inlet layer"
                                    onActivated: panel.inletLayerRequested(currentText)
                                }
                                Text {
                                    text: "Node ID field: " + (panel.nodeIdField || "Not configured")
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
                                          ? "Selection mode is active. Tap inlet points to add or remove them, then tap Done on the map."
                                          : "Tap only the inlet points that define the prediction area. A minimum of three is required."
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 54
                                    text: panel.inletSelectionActive ? "Return to map selection" : "Select inlets on map"
                                    enabled: panel.projectEnabled && panel.inletLayerName.length > 0 && !panel.predictionBusy()
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
                                    enabled: panel.projectEnabled && panel.selectedCount >= 3 && !panel.predictionBusy()
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
                                    columns: 3
                                    visible: panel.predictionSummary !== null
                                    columnSpacing: 8
                                    rowSpacing: 4

                                    Text { text: "Selected"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: "Predicted"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: "Potential"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
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
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: !panel.mockMode && panel.predictionSummary !== null
                                    text: "The API returns only pipes at or above the selected threshold; the potential-pipe count is not available."
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
                                    text: "Choose a map location or the current GNSS position. Pipe midpoint selection will use this same point workflow when the production result layer is connected."
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
                                    enabled: panel.projectEnabled
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: panel.pickAssessmentLocationRequested()
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: "Use current GNSS location"
                                    enabled: panel.projectEnabled
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
                                    text: "The first prototype uses a fixed 16-inch cast-iron nominal diameter. Material and gauge inputs will become editable after the production PyPASS contract is connected."
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 56
                                    text: "Run service-life assessment"
                                    enabled: panel.projectEnabled && panel.assessmentLocationLabel !== "No location selected"
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: panel.runAssessmentRequested()
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
                                        text: "Mock assessment preview"
                                        color: panel.ink
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 58
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: "#FFF3D9"
                                        Text { anchors.centerIn: parent; text: "MOCK"; color: panel.warning; font.pixelSize: 11; font.bold: true }
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 3
                                    columnSpacing: 8
                                    Text { text: "pH"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: "Resistivity"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: "Chloride"; color: panel.mutedInk; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: panel.assessmentResult ? panel.assessmentResult.soil.ph.toFixed(1) : "—"; color: panel.ink; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: panel.assessmentResult ? panel.assessmentResult.soil.resistivity_ohm_cm + " Ω·cm" : "—"; color: panel.ink; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                    Text { text: panel.assessmentResult ? panel.assessmentResult.soil.chloride : "—"; color: panel.ink; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
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
                                            text: modelData.years.toFixed(1) + " yr"
                                            color: panel.primaryDark
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "These deterministic values exist only to test the mobile interface. They are not engineering estimates or material recommendations."
                                    color: panel.warning
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
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
                                    text: "App-wide plugin behavior is controlled by the active project's DeepPipe properties. This keeps one plugin reusable across cities while allowing each project to map its own layers and fields."
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                Text { text: "Inlet layer"; color: panel.mutedInk; font.pixelSize: 12 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    enabled: panel.projectEnabled && panel.layerNames.length > 0
                                    model: panel.layerNames
                                    currentIndex: Math.max(0, panel.layerNames.indexOf(panel.inletLayerName))
                                    onActivated: panel.inletLayerRequested(currentText)
                                }
                                Text { text: "Node ID field"; color: panel.mutedInk; font.pixelSize: 12 }
                                TextField {
                                    id: nodeField
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: panel.nodeIdField
                                    placeholderText: "node_id"
                                    enabled: !panel.predictionBusy()
                                    onEditingFinished: panel.nodeIdFieldRequested(text.trim())
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
                                        Text { text: "Assessment remains mock in this version"; color: panel.mutedInk; font.pixelSize: 11 }
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
                                Text { Layout.fillWidth: true; text: "Touch-first inlet selection · resumable Prediction jobs · mock Assessment"; color: panel.mutedInk; font.pixelSize: 12; wrapMode: Text.WordWrap }
                            }
                        }

                        Item { Layout.preferredHeight: 18 }
                    }
                }
            }
        }
    }
}
