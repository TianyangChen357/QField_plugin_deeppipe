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
    property var predictionAttributeTable: ({ columns: [], rows: [] })
    property string completedJobId: ""
    property var predictionConfig: ({})
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
    property string apiConnectionStatus: "unknown"
    property string apiConnectionMessage: "Not checked"
    property string passApiConnectionStatus: "unknown"
    property string passApiConnectionMessage: "Not checked"
    property string rasterStatus: "idle"
    property string rasterMessage: "No PyPASS raster has been added by the plugin."
    property var rasterLayerNames: []
    property string activeJobId: ""
    property string pluginVersion: "0.5.13"

    signal closeRequested()
    signal refreshProjectRequested()
    signal inletLayerRequested(string layerId)
    signal nodeIdFieldRequested(string fieldName)
    signal confirmProjectMappingRequested()
    signal selectInletsRequested()
    signal finishSelectionRequested()
    signal clearSelectionRequested()
    signal predictionSettingsRequested(var settings)
    signal runPredictionRequested()
    signal cancelPredictionRequested()
    signal removePredictionLayerRequested()
    signal exportPredictionRequested()
    signal sharePredictionExportRequested()
    signal downloadPredictionZipRequested()
    signal pickAssessmentLocationRequested()
    signal useGnssRequested()
    signal assessmentInputsRequested(real nominalDiameter, int gauge, string materialId, int minimumYears)
    signal runAssessmentRequested()
    signal addPassVariableRasterRequested(string variableId, string name)
    signal addPassServiceLifeRasterRequested()
    signal removeRasterLayersRequested()
    signal testApiRequested()

    // UNC Charlotte brand colors. The official digital palette uses Charlotte
    // Green and Niner Gold as the primary colors, with Quartz White and Ore
    // Black for high-contrast surfaces and text.
    readonly property color charlotteGreen: "#005035"
    readonly property color ninerGold: "#A49665"
    readonly property color quartzWhite: "#FFFFFF"
    readonly property color oreBlack: "#101820"
    readonly property color jasper: "#F1E6B2"
    readonly property color pineGreen: "#899064"
    readonly property color skyBlue: "#007377"
    readonly property color clayRed: "#802F2D"

    readonly property color ink: oreBlack
    readonly property color mutedInk: "#4B5D56"
    readonly property color surface: quartzWhite
    readonly property color canvas: "#F4F6F4"
    readonly property color primary: charlotteGreen
    readonly property color primaryDark: "#003D29"
    readonly property color accent: ninerGold
    readonly property color divider: "#CFD9D3"
    readonly property color success: charlotteGreen
    readonly property color warning: "#735900"
    readonly property color danger: clayRed
    readonly property color disabledSurface: "#EEF2EF"
    readonly property var passMaterialIds: ["rcp", "cast_iron", "plastic", "galvanized", "aluminized_csp", "aluminum", "steel"]
    readonly property var passMaterialNames: ["RCP", "Cast Iron", "HDPE / PP / PVC", "Galvanized", "Aluminized CSP", "Aluminum", "Steel"]
    property var assessmentGaugeOptions: []
    property bool assessmentMaterialRequiresGauge: false
    property string assessmentMaterialName: "RCP"
    readonly property var neighborValues: [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
    readonly property var serviceLifeYearValues: [0, 10, 20, 30, 40, 50, 75, 100]

    function attributeCellText(value) {
        if (value === undefined || value === null || value === "") return "—";
        if (typeof value === "number") {
            if (!Number.isFinite(value)) return "—";
            return Math.abs(value) < 1000000 ? String(Number(value.toFixed(6))) : String(value);
        }
        if (typeof value === "object") return JSON.stringify(value);
        return String(value);
    }

    function attributeColumnWidth(key) {
        if (key === "__row") return 58;
        if (key === "deeppipe_outcome") return 112;
        if (key === "node_u" || key === "node_v") return 116;
        if (key === "prob" || key === "probability") return 132;
        return 124;
    }

    function attributeTableWidth() {
        var columns = predictionAttributeTable && Array.isArray(predictionAttributeTable.columns)
                ? predictionAttributeTable.columns : [];
        var width = 0;
        for (var index = 0; index < columns.length; index += 1) {
            width += attributeColumnWidth(columns[index].key);
        }
        return Math.max(width, 320);
    }

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

    function apiStatusColor(status) {
        var state = String(status || "unknown");
        if (state === "ok") return success;
        if (state === "failed") return danger;
        if (state === "checking") return warning;
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

    function requestPredictionSettings() {
        predictionSettingsRequested({
            model_type: String(modelTypeBox.currentText || "GNN").toLowerCase(),
            max_search_radius: distanceSlider.value,
            classification_threshold: thresholdSlider.value,
            threshold_tolerance: toleranceSlider.value,
            road_half_width_ft: roadWidthSlider.value,
            k_neighbors: Number(neighborsBox.currentText),
            with_mst: mstSwitch.checked,
            prob_weight: probabilityWeightSlider.value,
            // Elevation is intentionally fixed at zero in the mobile preset.
            // The API field remains present for contract compatibility, while
            // users control only GNN probability and length weighting.
            elev_weight: 0,
            length_weight: lengthWeightSlider.value
        });
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

                    Button {
                        id: guideButton
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 42
                        text: "Guide"
                        font.pixelSize: 13
                        font.bold: true
                        Accessible.name: "Open DeepPipe guide"

                        contentItem: Text {
                            text: guideButton.text
                            color: panel.charlotteGreen
                            font: guideButton.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 9
                            color: guideButton.down ? panel.disabledSurface : panel.surface
                            border.color: panel.charlotteGreen
                            border.width: 1
                        }

                        onClicked: guidePopup.open()
                    }

                    Button {
                        id: closeButton
                        Layout.preferredWidth: 84
                        Layout.preferredHeight: 42
                        text: "Close"
                        font.pixelSize: 14
                        font.bold: true
                        Accessible.name: "Close DeepPipe"

                        contentItem: Text {
                            text: closeButton.text
                            color: panel.quartzWhite
                            font: closeButton.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 9
                            color: closeButton.down ? panel.primaryDark : panel.primary
                            border.color: panel.ninerGold
                            border.width: 1
                        }

                        onClicked: panel.closeRequested()
                    }
                }
            }

            TabBar {
                id: tabBar
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                background: Rectangle {
                    color: panel.surface
                    border.color: panel.divider
                    border.width: 1
                }

                TabButton {
                    id: setupTab
                    text: "Configuration"
                    font.bold: checked
                    height: 52

                    contentItem: Text {
                        text: setupTab.text
                        color: setupTab.checked ? panel.quartzWhite : panel.charlotteGreen
                        font.pixelSize: 12
                        font.bold: setupTab.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    background: Rectangle {
                        color: setupTab.checked ? panel.charlotteGreen : panel.surface
                        border.color: setupTab.checked ? panel.charlotteGreen : panel.divider
                        border.width: 1
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 3
                            color: panel.ninerGold
                            visible: setupTab.checked
                        }
                    }
                }
                TabButton {
                    id: predictionTab
                    text: "Pipeline Prediction"
                    font.bold: checked
                    height: 52

                    contentItem: Text {
                        text: predictionTab.text
                        color: predictionTab.checked ? panel.quartzWhite : panel.charlotteGreen
                        font.pixelSize: 12
                        font.bold: predictionTab.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    background: Rectangle {
                        color: predictionTab.checked ? panel.charlotteGreen : panel.surface
                        border.color: predictionTab.checked ? panel.charlotteGreen : panel.divider
                        border.width: 1
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 3
                            color: panel.ninerGold
                            visible: predictionTab.checked
                        }
                    }
                }
                TabButton {
                    id: assessmentTab
                    text: "Service Life Assessment"
                    font.bold: checked
                    height: 52

                    contentItem: Text {
                        text: assessmentTab.text
                        color: assessmentTab.checked ? panel.quartzWhite : panel.charlotteGreen
                        font.pixelSize: 12
                        font.bold: assessmentTab.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    background: Rectangle {
                        color: assessmentTab.checked ? panel.charlotteGreen : panel.surface
                        border.color: assessmentTab.checked ? panel.charlotteGreen : panel.divider
                        border.width: 1
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 3
                            color: panel.ninerGold
                            visible: assessmentTab.checked
                        }
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                // Content remains grouped by workflow below; the tab order is
                // Configuration → Pipeline Prediction → Service Life Assessment.
                currentIndex: [2, 0, 1][tabBar.currentIndex]

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
                                        text: panel.projectReady ? "Refresh" : "Configuration"
                                        flat: true
                                        implicitHeight: 44
                                        onClicked: {
                                            if (panel.projectReady) panel.refreshProjectRequested();
                                            else tabBar.currentIndex = 0;
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
                                        text: "1  Select inlets on the map"
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
                                          : "Using " + (panel.inletLayerName || "the inlet layer configured in Configuration") +
                                            ". Select individual inlets, drag a box around many points, or add every inlet currently visible. A minimum of three is required."
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
                                    text: "2  Prediction settings"
                                    color: panel.ink
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "All model controls are optional. The values below start with the DeepPipe preset and are saved for this project on this device."
                                    color: panel.mutedInk
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                                Text { text: "Model"; color: panel.mutedInk; font.pixelSize: 12 }
                                ComboBox {
                                    id: modelTypeBox
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    model: ["GNN", "MLP"]
                                    currentIndex: ["gnn", "mlp"].indexOf(String(panel.predictionConfig.model_type || "gnn").toLowerCase())
                                    enabled: !panel.predictionBusy()
                                    palette.text: panel.ink
                                    palette.buttonText: panel.ink
                                    palette.highlight: panel.charlotteGreen
                                    palette.highlightedText: panel.quartzWhite
                                    palette.base: panel.surface
                                    palette.alternateBase: panel.canvas
                                    contentItem: Text {
                                        leftPadding: 14
                                        rightPadding: 42
                                        text: modelTypeBox.displayText
                                        color: modelTypeBox.enabled ? panel.ink : panel.mutedInk
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        radius: 8
                                        color: modelTypeBox.enabled ? panel.surface : panel.disabledSurface
                                        border.color: modelTypeBox.activeFocus ? panel.ninerGold : panel.divider
                                        border.width: modelTypeBox.activeFocus ? 2 : 1
                                    }
                                    indicator: Text {
                                        x: modelTypeBox.width - width - 14
                                        y: (modelTypeBox.height - height) / 2
                                        text: "▾"
                                        color: modelTypeBox.enabled ? panel.charlotteGreen : panel.mutedInk
                                        font.pixelSize: 16
                                    }
                                    onActivated: panel.requestPredictionSettings()
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
                                    value: panel.predictionConfig.max_search_radius !== undefined
                                           ? panel.predictionConfig.max_search_radius : panel.maxSearchRadius
                                    enabled: !panel.predictionBusy()
                                    implicitHeight: 44
                                    onMoved: panel.requestPredictionSettings()
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
                                    value: panel.predictionConfig.classification_threshold !== undefined
                                           ? panel.predictionConfig.classification_threshold : panel.confidenceThreshold
                                    enabled: !panel.predictionBusy()
                                    implicitHeight: 44
                                    onMoved: panel.requestPredictionSettings()
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: "Threshold tolerance"; color: panel.ink; font.pixelSize: 14 }
                                    Text { text: toleranceSlider.value.toFixed(2); color: panel.primary; font.pixelSize: 14; font.bold: true }
                                }
                                Slider {
                                    id: toleranceSlider
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 0.5
                                    stepSize: 0.05
                                    value: panel.predictionConfig.threshold_tolerance !== undefined ? panel.predictionConfig.threshold_tolerance : 0.3
                                    enabled: !panel.predictionBusy()
                                    implicitHeight: 44
                                    onMoved: panel.requestPredictionSettings()
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: "Road half-width"; color: panel.ink; font.pixelSize: 14 }
                                    Text { text: Math.round(roadWidthSlider.value) + " ft"; color: panel.primary; font.pixelSize: 14; font.bold: true }
                                }
                                Slider {
                                    id: roadWidthSlider
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 500
                                    stepSize: 25
                                    value: panel.predictionConfig.road_half_width_ft !== undefined ? panel.predictionConfig.road_half_width_ft : 100
                                    enabled: !panel.predictionBusy()
                                    implicitHeight: 44
                                    onMoved: panel.requestPredictionSettings()
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: "Number of neighbors (k)"; color: panel.ink; font.pixelSize: 14 }
                                    ComboBox {
                                        id: neighborsBox
                                        Layout.preferredWidth: 118
                                        implicitHeight: 46
                                        model: panel.neighborValues
                                        currentIndex: Math.max(0, panel.neighborValues.indexOf(Number(panel.predictionConfig.k_neighbors || 12)))
                                        enabled: !panel.predictionBusy()
                                        palette.text: panel.ink
                                        palette.buttonText: panel.ink
                                        palette.highlight: panel.charlotteGreen
                                        palette.highlightedText: panel.quartzWhite
                                        palette.base: panel.surface
                                        contentItem: Text {
                                            text: neighborsBox.displayText
                                            color: neighborsBox.enabled ? panel.ink : panel.mutedInk
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 14
                                        }
                                        background: Rectangle {
                                            radius: 8
                                            color: neighborsBox.enabled ? panel.surface : panel.disabledSurface
                                            border.color: neighborsBox.activeFocus ? panel.ninerGold : panel.divider
                                            border.width: neighborsBox.activeFocus ? 2 : 1
                                        }
                                        onActivated: panel.requestPredictionSettings()
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: "Enable MST post-processing"; color: panel.ink; font.pixelSize: 14 }
                                    Switch {
                                        id: mstSwitch
                                        checked: panel.predictionConfig.with_mst !== undefined ? panel.predictionConfig.with_mst : true
                                        enabled: !panel.predictionBusy()
                                        Accessible.name: "Enable minimum spanning tree post-processing"
                                        onClicked: panel.requestPredictionSettings()
                                    }
                                }
                                Text {
                                    text: "Weighting (automatically normalized to 100%)"
                                    color: panel.mutedInk
                                    font.pixelSize: 12
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: "GNN probability"; color: panel.ink; font.pixelSize: 13 }
                                    Text { text: Math.round(probabilityWeightSlider.value * 100) + "%"; color: panel.primary; font.pixelSize: 13; font.bold: true }
                                }
                                Slider {
                                    id: probabilityWeightSlider
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 1
                                    stepSize: 0.05
                                    value: panel.predictionConfig.prob_weight !== undefined ? panel.predictionConfig.prob_weight : 0.5
                                    enabled: !panel.predictionBusy()
                                    implicitHeight: 38
                                    onMoved: panel.requestPredictionSettings()
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: "Length"; color: panel.ink; font.pixelSize: 13 }
                                    Text { text: Math.round(lengthWeightSlider.value * 100) + "%"; color: panel.primary; font.pixelSize: 13; font.bold: true }
                                }
                                Slider {
                                    id: lengthWeightSlider
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 1
                                    stepSize: 0.05
                                    value: panel.predictionConfig.length_weight !== undefined ? panel.predictionConfig.length_weight : 0.5
                                    enabled: !panel.predictionBusy()
                                    implicitHeight: 38
                                    onMoved: panel.requestPredictionSettings()
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Default preset: GNN · k=12 · MST on · GNN probability 50% · length 50%."
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
                                        text: panel.predictionSummary ? panel.predictionSummary.potential : "—"
                                        color: panel.warning
                                        font.pixelSize: 20
                                        font.bold: true
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: panel.predictionSummary !== null
                                    text: "Predicted = above-threshold GNN candidates retained by MST. Potential = above-threshold GNN candidates not retained by MST."
                                    color: panel.mutedInk
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: panel.predictionResultLayer.length > 0
                                    spacing: 14
                                    Rectangle { Layout.preferredWidth: 18; Layout.preferredHeight: 6; radius: 3; color: panel.charlotteGreen }
                                    Text { text: "Predicted"; color: panel.ink; font.pixelSize: 12 }
                                    Rectangle { Layout.preferredWidth: 18; Layout.preferredHeight: 6; radius: 3; color: "#F4C430" }
                                    Text { text: "Potential"; color: panel.ink; font.pixelSize: 12; Layout.fillWidth: true }
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
                                    text: "View result attribute table"
                                    visible: panel.predictionAttributeTable &&
                                             Array.isArray(panel.predictionAttributeTable.rows) &&
                                             panel.predictionAttributeTable.rows.length > 0
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: resultTablePopup.open()
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: "Download complete job ZIP"
                                    visible: !panel.mockMode && panel.completedJobId.length > 0
                                    font.bold: true
                                    palette.button: panel.accent
                                    palette.buttonText: panel.oreBlack
                                    onClicked: panel.downloadPredictionZipRequested()
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: !panel.mockMode && panel.completedJobId.length > 0
                                    text: "The ZIP is supplied by the Prediction API and contains the job's Structures.geojson, Pipes.geojson, and log.txt files."
                                    color: panel.mutedInk
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
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
                                    text: "Choose the pipe material first. Gauge size is enabled only when that material provides gauge options; fixed materials do not require a gauge."
                                    color: panel.mutedInk
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                                Text { text: "Pipe material"; color: panel.mutedInk; font.pixelSize: 12 }
                                ComboBox {
                                    id: assessmentMaterialBox
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    model: panel.passMaterialNames
                                    currentIndex: Math.max(0, panel.passMaterialIds.indexOf(panel.assessmentMaterialId))
                                    enabled: !panel.assessmentBusy()
                                    palette.text: panel.ink
                                    palette.buttonText: panel.ink
                                    palette.highlight: panel.charlotteGreen
                                    palette.highlightedText: panel.quartzWhite
                                    palette.base: panel.surface
                                    palette.alternateBase: panel.canvas
                                    contentItem: Text {
                                        leftPadding: 14
                                        rightPadding: 42
                                        text: assessmentMaterialBox.displayText
                                        color: assessmentMaterialBox.enabled ? panel.ink : panel.mutedInk
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                    background: Rectangle {
                                        radius: 8
                                        color: assessmentMaterialBox.enabled ? panel.surface : panel.disabledSurface
                                        border.color: assessmentMaterialBox.activeFocus ? panel.ninerGold : panel.divider
                                        border.width: assessmentMaterialBox.activeFocus ? 2 : 1
                                    }
                                    indicator: Text {
                                        x: assessmentMaterialBox.width - width - 14
                                        y: (assessmentMaterialBox.height - height) / 2
                                        text: "▾"
                                        color: assessmentMaterialBox.enabled ? panel.charlotteGreen : panel.mutedInk
                                        font.pixelSize: 16
                                    }
                                    onActivated: panel.assessmentInputsRequested(
                                                     Number(panel.assessmentNominalDiameter),
                                                     panel.assessmentGauge,
                                                     panel.passMaterialIds[currentIndex],
                                                     panel.assessmentMinimumYears)
                                }
                                Text { text: "Gauge size"; color: panel.mutedInk; font.pixelSize: 12 }
                                ComboBox {
                                    id: assessmentGaugeBox
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    model: panel.assessmentGaugeOptions
                                    currentIndex: panel.assessmentGaugeOptions.indexOf(panel.assessmentGauge)
                                    enabled: panel.assessmentMaterialRequiresGauge && !panel.assessmentBusy()
                                    displayText: panel.assessmentMaterialRequiresGauge && currentIndex >= 0
                                                 ? currentText : "Not applicable for this material"
                                    palette.text: panel.ink
                                    palette.buttonText: panel.ink
                                    palette.highlight: panel.charlotteGreen
                                    palette.highlightedText: panel.quartzWhite
                                    palette.base: panel.surface
                                    palette.alternateBase: panel.canvas
                                    contentItem: Text {
                                        leftPadding: 14
                                        rightPadding: 42
                                        text: assessmentGaugeBox.displayText
                                        color: assessmentGaugeBox.enabled ? panel.ink : panel.mutedInk
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        radius: 8
                                        color: assessmentGaugeBox.enabled ? panel.surface : panel.disabledSurface
                                        border.color: assessmentGaugeBox.activeFocus ? panel.ninerGold : panel.divider
                                        border.width: assessmentGaugeBox.activeFocus ? 2 : 1
                                    }
                                    indicator: Text {
                                        x: assessmentGaugeBox.width - width - 14
                                        y: (assessmentGaugeBox.height - height) / 2
                                        text: assessmentGaugeBox.enabled ? "▾" : "—"
                                        color: assessmentGaugeBox.enabled ? panel.charlotteGreen : panel.mutedInk
                                        font.pixelSize: 16
                                    }
                                    onActivated: panel.assessmentInputsRequested(
                                                     Number(panel.assessmentNominalDiameter),
                                                     Number(currentText),
                                                     panel.assessmentMaterialId,
                                                     panel.assessmentMinimumYears)
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "The live endpoint keeps its internal cast-iron reference size at 16 in; the material and gauge selections control the comparison and hosted raster workflow."
                                    color: panel.mutedInk
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
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
                                             panel.assessmentMaterialId.length > 0
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: {
                                        panel.assessmentInputsRequested(
                                                    Number(panel.assessmentNominalDiameter),
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
                                    text: "Add live PyPASS soil or service-life tiles to the QField map. The material and gauge come from step 2; choose the minimum service-life threshold here."
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

                                Text { text: "Selected service-life layer"; color: panel.mutedInk; font.pixelSize: 12 }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 50
                                    radius: 8
                                    color: panel.disabledSurface
                                    border.color: panel.divider
                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        text: panel.assessmentMaterialName +
                                              (panel.assessmentMaterialRequiresGauge
                                               ? " · gauge " + panel.assessmentGauge
                                               : " · gauge not applicable")
                                        color: panel.ink
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                }
                                Text { text: "Minimum service life (years)"; color: panel.mutedInk; font.pixelSize: 12 }
                                ComboBox {
                                    id: minimumYearsBox
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    model: panel.serviceLifeYearValues
                                    currentIndex: Math.max(0, panel.serviceLifeYearValues.indexOf(panel.assessmentMinimumYears))
                                    enabled: !panel.predictionBusy() && !panel.assessmentBusy() && panel.rasterStatus !== "loading"
                                    palette.text: panel.ink
                                    palette.buttonText: panel.ink
                                    palette.highlight: panel.charlotteGreen
                                    palette.highlightedText: panel.quartzWhite
                                    palette.base: panel.surface
                                    palette.alternateBase: panel.canvas
                                    contentItem: Text {
                                        leftPadding: 14
                                        rightPadding: 42
                                        text: minimumYearsBox.displayText + " years"
                                        color: minimumYearsBox.enabled ? panel.ink : panel.mutedInk
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        radius: 8
                                        color: minimumYearsBox.enabled ? panel.surface : panel.disabledSurface
                                        border.color: minimumYearsBox.activeFocus ? panel.ninerGold : panel.divider
                                        border.width: minimumYearsBox.activeFocus ? 2 : 1
                                    }
                                    indicator: Text {
                                        x: minimumYearsBox.width - width - 14
                                        y: (minimumYearsBox.height - height) / 2
                                        text: "▾"
                                        color: minimumYearsBox.enabled ? panel.charlotteGreen : panel.mutedInk
                                        font.pixelSize: 16
                                    }
                                    onActivated: panel.assessmentInputsRequested(
                                                     Number(panel.assessmentNominalDiameter),
                                                     panel.assessmentGauge,
                                                     panel.assessmentMaterialId,
                                                     Number(currentText))
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
                                                    Number(panel.assessmentNominalDiameter),
                                                    panel.assessmentGauge,
                                                    panel.assessmentMaterialId,
                                                    Number(minimumYearsBox.currentText) || 0);
                                        panel.addPassServiceLifeRasterRequested();
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
                                    id: setupLayerBox
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    enabled: panel.hasProject && panel.layerNames.length > 0 && !panel.predictionBusy()
                                    model: panel.layerNames
                                    currentIndex: panel.layerIds.indexOf(panel.inletLayerId)
                                    displayText: currentIndex >= 0 ? currentText : "Choose a point layer"
                                    palette.text: panel.ink
                                    palette.buttonText: panel.ink
                                    palette.highlight: panel.charlotteGreen
                                    palette.highlightedText: panel.quartzWhite
                                    palette.base: panel.surface
                                    palette.alternateBase: panel.canvas
                                    contentItem: Text {
                                        leftPadding: 14
                                        rightPadding: 42
                                        text: setupLayerBox.displayText
                                        color: setupLayerBox.enabled ? panel.ink : panel.mutedInk
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                    background: Rectangle {
                                        radius: 8
                                        color: setupLayerBox.enabled ? panel.surface : panel.disabledSurface
                                        border.color: setupLayerBox.activeFocus ? panel.ninerGold : panel.divider
                                        border.width: setupLayerBox.activeFocus ? 2 : 1
                                    }
                                    indicator: Text {
                                        x: setupLayerBox.width - width - 14
                                        y: (setupLayerBox.height - height) / 2
                                        text: "▾"
                                        color: setupLayerBox.enabled ? panel.charlotteGreen : panel.mutedInk
                                        font.pixelSize: 16
                                    }
                                    onActivated: panel.inletLayerRequested(panel.layerIds[currentIndex])
                                }
                                Text { text: "Unique inlet ID field"; color: panel.mutedInk; font.pixelSize: 12 }
                                ComboBox {
                                    id: setupFieldBox
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    enabled: panel.inletLayerId.length > 0 && panel.fieldNames.length > 0 && !panel.predictionBusy()
                                    model: panel.fieldNames
                                    currentIndex: panel.fieldNames.indexOf(panel.nodeIdField)
                                    displayText: currentIndex >= 0 ? currentText : "Choose an ID field"
                                    palette.text: panel.ink
                                    palette.buttonText: panel.ink
                                    palette.highlight: panel.charlotteGreen
                                    palette.highlightedText: panel.quartzWhite
                                    palette.base: panel.surface
                                    palette.alternateBase: panel.canvas
                                    contentItem: Text {
                                        leftPadding: 14
                                        rightPadding: 42
                                        text: setupFieldBox.displayText
                                        color: setupFieldBox.enabled ? panel.ink : panel.mutedInk
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                    background: Rectangle {
                                        radius: 8
                                        color: setupFieldBox.enabled ? panel.surface : panel.disabledSurface
                                        border.color: setupFieldBox.activeFocus ? panel.ninerGold : panel.divider
                                        border.width: setupFieldBox.activeFocus ? 2 : 1
                                    }
                                    indicator: Text {
                                        x: setupFieldBox.width - width - 14
                                        y: (setupFieldBox.height - height) / 2
                                        text: "▾"
                                        color: setupFieldBox.enabled ? panel.charlotteGreen : panel.mutedInk
                                        font.pixelSize: 16
                                    }
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
                                    text: "Service status"
                                    color: panel.ink
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "The plugin uses its built-in Prediction and PyPASS service endpoints. You do not need to enter API origins here."
                                    color: panel.mutedInk
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 58
                                    radius: 9
                                    color: "#F7F9F8"
                                    border.color: panel.divider
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        Rectangle {
                                            Layout.preferredWidth: 10
                                            Layout.preferredHeight: 10
                                            radius: 5
                                            color: panel.apiStatusColor(panel.apiConnectionStatus)
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text { text: "Prediction API"; color: panel.ink; font.pixelSize: 13; font.bold: true }
                                            Text { text: panel.apiConnectionMessage; color: panel.mutedInk; font.pixelSize: 12; elide: Text.ElideRight }
                                        }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 58
                                    radius: 9
                                    color: "#F7F9F8"
                                    border.color: panel.divider
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        Rectangle {
                                            Layout.preferredWidth: 10
                                            Layout.preferredHeight: 10
                                            radius: 5
                                            color: panel.apiStatusColor(panel.passApiConnectionStatus)
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text { text: "PyPASS API"; color: panel.ink; font.pixelSize: 13; font.bold: true }
                                            Text { text: panel.passApiConnectionMessage; color: panel.mutedInk; font.pixelSize: 12; elide: Text.ElideRight }
                                        }
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
                                        Text { text: "Prediction mode"; color: panel.mockMode ? panel.warning : panel.success; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
                                        Text { text: panel.mockMode ? "Local preview" : "Live API"; color: panel.mockMode ? panel.warning : panel.success; font.pixelSize: 13 }
                                    }
                                }
                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    text: panel.apiConnectionStatus === "checking" || panel.passApiConnectionStatus === "checking"
                                          ? "Checking services…" : "Check API status"
                                    enabled: panel.apiConnectionStatus !== "checking" && panel.passApiConnectionStatus !== "checking" &&
                                             panel.activeJobId.length === 0 && !panel.predictionBusy()
                                    font.bold: true
                                    palette.button: panel.primary
                                    palette.buttonText: "white"
                                    onClicked: panel.testApiRequested()
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "The live endpoints currently do not advertise authentication. Do not submit sensitive field data; prediction and service-life outputs require engineering review."
                                    color: panel.warning
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: panel.mockMode
                                    text: "Local preview mode is active for this project. Set DeepPipe api_mode to live before calling the Prediction API."
                                    color: panel.mutedInk
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

    Popup {
        id: resultTablePopup
        parent: panel
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(panel.width - 16, 720)
        height: Math.min(panel.height - 40, 680)
        x: (panel.width - width) / 2
        y: Math.max(8, (panel.height - height) / 2)

        background: Rectangle {
            radius: 16
            color: panel.surface
            border.color: panel.charlotteGreen
            border.width: 2
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Prediction result attributes"
                    color: panel.ink
                    font.pixelSize: 18
                    font.bold: true
                }
                Button {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 40
                    text: "Close"
                    onClicked: resultTablePopup.close()
                }
            }

            Text {
                Layout.fillWidth: true
                text: {
                    var rows = panel.predictionAttributeTable && Array.isArray(panel.predictionAttributeTable.rows)
                            ? panel.predictionAttributeTable.rows.length : 0;
                    var columns = panel.predictionAttributeTable && Array.isArray(panel.predictionAttributeTable.columns)
                            ? panel.predictionAttributeTable.columns.length : 0;
                    return rows + " pipe" + (rows === 1 ? "" : "s") + " · " + columns + " fields · swipe horizontally and vertically";
                }
                color: panel.mutedInk
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 8
                color: "#F7F9F8"
                border.color: panel.divider
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    Rectangle { Layout.preferredWidth: 18; Layout.preferredHeight: 6; radius: 3; color: panel.charlotteGreen }
                    Text { text: "Predicted"; color: panel.ink; font.pixelSize: 11 }
                    Rectangle { Layout.preferredWidth: 18; Layout.preferredHeight: 6; radius: 3; color: "#F4C430" }
                    Text { text: "Potential"; color: panel.ink; font.pixelSize: 11; Layout.fillWidth: true }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Flickable {
                    id: resultTableHorizontal
                    anchors.fill: parent
                    clip: true
                    contentWidth: panel.attributeTableWidth()
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    Item {
                        width: resultTableHorizontal.contentWidth
                        height: resultTableHorizontal.height

                        Rectangle {
                            id: resultTableHeader
                            width: parent.width
                            height: 44
                            color: panel.charlotteGreen

                            Row {
                                anchors.fill: parent
                                Repeater {
                                    model: panel.predictionAttributeTable && Array.isArray(panel.predictionAttributeTable.columns)
                                           ? panel.predictionAttributeTable.columns : []
                                    delegate: Rectangle {
                                        property var columnInfo: modelData
                                        width: panel.attributeColumnWidth(columnInfo.key)
                                        height: resultTableHeader.height
                                        color: "transparent"
                                        border.color: "#4DFFFFFF"
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            text: columnInfo.label
                                            color: "white"
                                            font.pixelSize: 11
                                            font.bold: true
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignLeft
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        ListView {
                            id: resultAttributeRows
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: resultTableHeader.bottom
                            anchors.bottom: parent.bottom
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: panel.predictionAttributeTable && Array.isArray(panel.predictionAttributeTable.rows)
                                   ? panel.predictionAttributeTable.rows : []
                            ScrollBar.vertical: ScrollBar {}

                            delegate: Rectangle {
                                id: attributeRow
                                property var rowValues: modelData
                                width: resultAttributeRows.width
                                height: 44
                                color: index % 2 === 0 ? panel.surface : "#F4F7F5"

                                Row {
                                    anchors.fill: parent
                                    Repeater {
                                        model: panel.predictionAttributeTable && Array.isArray(panel.predictionAttributeTable.columns)
                                               ? panel.predictionAttributeTable.columns : []
                                        delegate: Rectangle {
                                            property var columnInfo: modelData
                                            property string cellValue: panel.attributeCellText(attributeRow.rowValues[columnInfo.key])
                                            width: panel.attributeColumnWidth(columnInfo.key)
                                            height: attributeRow.height
                                            color: "transparent"
                                            border.color: panel.divider
                                            Text {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                text: parent.cellValue
                                                color: parent.columnInfo.key === "deeppipe_outcome"
                                                       ? (parent.cellValue === "predicted" ? panel.charlotteGreen : panel.warning)
                                                       : panel.ink
                                                font.pixelSize: 11
                                                font.bold: parent.columnInfo.key === "deeppipe_outcome"
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ScrollBar.horizontal: ScrollBar {}
                }
            }
        }
    }

    Popup {
        id: guidePopup
        parent: panel
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(panel.width - 24, 440)
        height: Math.min(panel.height - 110, 570)
        x: (panel.width - width) / 2
        y: Math.max(10, (panel.height - height) / 2)

        background: Rectangle {
            radius: 16
            color: panel.surface
            border.color: panel.charlotteGreen
            border.width: 2
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "DeepPipe field guide"
                    color: panel.ink
                    font.pixelSize: 18
                    font.bold: true
                }
                Button {
                    id: guideCloseButton
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 40
                    text: "Close"
                    onClicked: guidePopup.close()
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: "Configuration"
                        color: panel.charlotteGreen
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Choose the point layer containing stormwater inlets and a stable unique ID field. For multiple users, a text UUID field is recommended; create it with uuid('WithoutBraces') and do not update it after the inlet is created."
                        color: panel.ink
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Pipeline Prediction"
                        color: panel.charlotteGreen
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Pipeline Prediction automatically uses the inlet layer saved in Configuration. Tap Select inlets on map. Tap an inlet to add or remove one; choose Box and drag a rectangle to add many; choose Visible to add all inlets in the current map view. Press Done when finished. At least three valid inlets are required."
                        color: panel.ink
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Prediction settings start with GNN, 500 ft, confidence 0.85, k=12, MST enabled, and 50% GNN probability / 50% length weighting. You can adjust these values before running the prediction."
                        color: panel.ink
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Results show only GNN-positive pipes at or above the selected confidence threshold. Green Predicted pipes were retained by MST; yellow Potential pipes passed the GNN threshold but were not retained by MST. Use View result attribute table for every returned field, or Download complete job ZIP for the server files."
                        color: panel.ink
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Service Life Assessment"
                        color: panel.charlotteGreen
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Choose a point on the map or use the current GNSS location. In Compare service-life estimates, select a material first. Gauge size is available only for materials that define gauge options; otherwise the control is disabled."
                        color: panel.ink
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Review hosted raster layers adds the live PyPASS soil or service-life tiles. Select a minimum service-life threshold and add the layer to the current QField map."
                        color: panel.ink
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "The Close button returns to QField. The service-status card in Configuration checks whether both APIs are online."
                        color: panel.mutedInk
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (!panel.projectReady) tabBar.currentIndex = 0;
    }

    onSetupStateChanged: {
        if (panel.setupState !== "ready") tabBar.currentIndex = 0;
    }
}
