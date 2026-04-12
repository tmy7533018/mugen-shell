import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../common" as Common
import "../ui" as UI

Item {
    id: root

    required property var modeManager
    property var theme
    property var icons
    property var settingsManager

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(420),
        "leftMargin": modeManager.scale(700),
        "rightMargin": modeManager.scale(700),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    property var blurPresets: []
    property bool isLoadingPresets: false
    property string currentPreset: ""

    function loadBlurPresets() {
        if (isLoadingPresets) return
        isLoadingPresets = true
        listPresetsProcess.running = true
        getCurrentPresetProcess.running = true
    }

    function getCurrentPreset() {
        getCurrentPresetProcess.running = true
    }

    function applyBlurPreset(presetName) {
        applyPresetProcess.command = [
            "bash",
            Quickshell.shellDir + "/scripts/blur-preset.sh",
            presetName
        ]
        applyPresetProcess.running = true
        root.resetAutoCloseTimer()
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("settings", root)
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("settings")) {
                if (settingsManager && settingsManager.autoCloseTimerEnabled) {
                    autoCloseTimer.restart()
                }
                loadBlurPresets()
            } else {
                autoCloseTimer.stop()
            }
        }
    }

    Timer {
        id: autoCloseTimer
        interval: settingsManager ? settingsManager.autoCloseTimerInterval : 5000
        running: false
        repeat: false
        onTriggered: {
            if (modeManager.isMode("settings")) {
                modeManager.closeAllModes()
            }
        }
    }

    Connections {
        target: settingsManager
        function onAutoCloseTimerIntervalChanged() {
            if (settingsManager) {
                autoCloseTimer.interval = settingsManager.autoCloseTimerInterval
            }
        }
    }

    function resetAutoCloseTimer() {
        if (modeManager.isMode("settings") && settingsManager && settingsManager.autoCloseTimerEnabled) {
            autoCloseTimer.restart()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("settings")
        visible: enabled
        hoverEnabled: true

        onClicked: {
            modeManager.closeAllModes()
        }

        onPositionChanged: {
            if (modeManager.isMode("settings")) {
                autoCloseTimer.restart()
            }
        }
    }

    Item {
        id: settingsLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
        z: 3

        focus: modeManager.isMode("settings")
        Keys.onPressed: (event) => {
            if (modeManager.isMode("settings")) {
                autoCloseTimer.restart()
            }
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            }
        }

        opacity: 0
        visible: opacity > 0.01

        states: [
            State {
                name: "visible"
                when: modeManager.isMode("settings")
                PropertyChanges { target: settingsLayer; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: 300 }
                    NumberAnimation {
                        property: "opacity"
                        duration: 400
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]

        Item {
            anchors.centerIn: parent
            width: Math.min(modeManager.scale(420), parent.width - modeManager.scale(64))
            height: parent.height - modeManager.scale(80)

            Rectangle {
                id: headerBackground
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: headerRow.height + 8
                z: 10
                color: "transparent"
            }

            RowLayout {
                id: headerRow
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: modeManager.scale(420)
                height: modeManager.scale(36)
                spacing: modeManager.scale(10)
                z: 11

                Common.GlowText {
                    text: "Settings"
                    font.pixelSize: modeManager.scale(20)
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1.5
                    color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)

                    enableGlow: true
                    glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                    glowSamples: 20
                    glowRadius: 12
                    glowSpread: 0.5
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: resetButton
                    property real baseWidth: resetText.implicitWidth + 24
                    Layout.preferredWidth: baseWidth
                    Layout.fillWidth: false
                    height: 28
                    color: Qt.rgba(0.90, 0.45, 0.55, resetMouseArea.containsMouse ? 0.3 : 0.2)
                    radius: height / 2

                    Behavior on color {
                        ColorAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        id: resetText
                        anchors.centerIn: parent
                        text: "Reset to Default"
                        color: Qt.rgba(0.95, 0.55, 0.65, resetMouseArea.containsMouse ? 1.0 : 0.85)
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"

                        Behavior on color {
                            ColorAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: resetMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (settingsManager) {
                                settingsManager.resetToDefault()
                            }
                            root.resetAutoCloseTimer()
                        }
                    }
                }
            }

            ListView {
                id: settingsList
                anchors.top: headerRow.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 16
                clip: true

                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }

                model: ListModel {
                    id: settingsModel
                }

                delegate: Loader {
                    width: settingsList.width
                    property int itemIndex: index
                    property bool isLastItem: index === settingsModel.count - 1
                    property bool isSecondLastItem: index === settingsModel.count - 2
                    sourceComponent: {
                        switch (model.type) {
                            case "theme": return themeSection
                            case "blur": return blurSection
                            case "timer": return timerSection
                            case "gradient": return gradientSection
                            case "animation": return animationSection
                            default: return null
                        }
                    }
                }

                Component.onCompleted: {
                    settingsModel.append({ "type": "theme" })
                    settingsModel.append({ "type": "blur" })
                    settingsModel.append({ "type": "timer" })
                    settingsModel.append({ "type": "gradient" })
                    settingsModel.append({ "type": "animation" })
                }
            }
        }
    }

    Component {
        id: themeSection

        Rectangle {
            width: parent ? parent.width : 420
            height: 64
            color: theme ? theme.surfaceGlass : Qt.rgba(0.15, 0.15, 0.20, 0.5)
            radius: 20
            border.width: 1
            border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "Dark Mode"
                    color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    font.weight: Font.Normal
                    font.letterSpacing: 0.5
                }

                Common.Switch {
                    id: themeSwitch
                    checked: theme ? theme.themeMode === "dark" : true
                    theme: root.theme

                    Connections {
                        target: root.theme
                        function onThemeModeChanged() {
                            if (root.theme) {
                                themeSwitch.checked = root.theme.themeMode === "dark"
                            }
                        }
                    }

                    onToggled: {
                        if (theme) {
                            if (checked && theme.themeMode !== "dark") {
                                theme.toggleThemeMode()
                                root.resetAutoCloseTimer()
                            } else if (!checked && theme.themeMode !== "light") {
                                theme.toggleThemeMode()
                                root.resetAutoCloseTimer()
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: blurSection

        Rectangle {
            id: blurSectionRect
            width: parent ? parent.width : 420
            height: blurSectionRect.isExpanded ? 120 : 64
            color: theme ? theme.surfaceGlass : Qt.rgba(0.15, 0.15, 0.20, 0.5)
            radius: 20
            border.width: 1
            border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
            clip: false

            property bool isExpanded: false

            Behavior on height {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                MouseArea {
                    Layout.fillWidth: true
                    Layout.preferredHeight: modeManager.scale(40)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        blurSectionRect.isExpanded = !blurSectionRect.isExpanded
                        root.resetAutoCloseTimer()
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            text: "Blur Preset"
                            color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                            font.pixelSize: 12
                            font.family: "M PLUS 2"
                            font.weight: Font.Normal
                            font.letterSpacing: 0.5
                        }

                        Text {
                            text: {
                                if (root.isLoadingPresets) {
                                    return "Loading..."
                                } else if (root.currentPreset && root.blurPresets.indexOf(root.currentPreset) >= 0) {
                                    return root.currentPreset
                                } else {
                                    return "Select preset"
                                }
                            }
                            color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                            font.pixelSize: 12
                            font.family: "M PLUS 2"
                            font.weight: Font.Medium
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: blurSectionRect.isExpanded ? 44 : 0
                    visible: blurSectionRect.isExpanded
                    opacity: blurSectionRect.isExpanded ? 1.0 : 0.0

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }

                    ListView {
                        id: presetList
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(contentWidth, parent.width)
                        height: parent.height
                        orientation: ListView.Horizontal
                        spacing: 8
                        clip: true
                        model: root.blurPresets
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: blurSectionRect.isExpanded && contentWidth > width

                        onVisibleChanged: {
                            if (visible && root.currentPreset) {
                                let index = root.blurPresets.indexOf(root.currentPreset)
                                if (index >= 0) {
                                    Qt.callLater(() => {
                                        presetList.currentIndex = index
                                        presetList.positionViewAtIndex(index, ListView.Center)
                                    })
                                }
                            }
                        }

                        delegate: Rectangle {
                            width: Math.max(presetText.implicitWidth + 24, 80)
                            height: 36
                            radius: 8
                            property bool isCurrent: modelData === root.currentPreset

                            color: presetMouseArea.containsMouse
                                ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                                : (isCurrent
                                    ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.95) : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                                    : (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15) : Qt.rgba(0.65, 0.55, 0.85, 0.15)))

                            border.width: isCurrent ? 1 : 0
                            border.color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            Text {
                                id: presetText
                                anchors.centerIn: parent
                                text: modelData
                                color: isCurrent
                                    ? (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                                    : (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.70))
                                font.pixelSize: 12
                                font.family: "M PLUS 2"
                                font.weight: isCurrent ? Font.Medium : Font.Normal
                            }

                            MouseArea {
                                id: presetMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.applyBlurPreset(modelData)
                                    blurSectionRect.isExpanded = false
                                    root.resetAutoCloseTimer()
                                }
                            }
                        }

                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            height: 4

                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: timerSection

        Rectangle {
            id: timerSectionRect
            width: parent ? parent.width : 420
            height: timerSectionRect.isExpanded ? 120 : 64
            color: theme ? theme.surfaceGlass : Qt.rgba(0.15, 0.15, 0.20, 0.5)
            radius: 20
            border.width: 1
            border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
            clip: false

            property bool isExpanded: false
            property var timerOptions: [
                { "label": "3 seconds", "value": 3000 },
                { "label": "5 seconds", "value": 5000 },
                { "label": "10 seconds", "value": 10000 },
                { "label": "15 seconds", "value": 15000 },
                { "label": "30 seconds", "value": 30000 },
                { "label": "Disabled", "value": 0 }
            ]

            Behavior on height {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                MouseArea {
                    Layout.fillWidth: true
                    Layout.preferredHeight: modeManager.scale(40)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        timerSectionRect.isExpanded = !timerSectionRect.isExpanded
                        root.resetAutoCloseTimer()
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            text: "Auto Close Timer"
                            color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                            font.pixelSize: 12
                            font.family: "M PLUS 2"
                            font.weight: Font.Normal
                            font.letterSpacing: 0.5
                        }

                        Text {
                            text: {
                                if (!settingsManager) return "..."
                                if (!settingsManager.autoCloseTimerEnabled || settingsManager.autoCloseTimerInterval === 0) {
                                    return "Disabled"
                                }
                                let interval = settingsManager.autoCloseTimerInterval
                                return (interval / 1000) + " seconds"
                            }
                            color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                            font.pixelSize: 12
                            font.family: "M PLUS 2"
                            font.weight: Font.Medium
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: timerSectionRect.isExpanded ? 44 : 0
                    visible: timerSectionRect.isExpanded
                    opacity: timerSectionRect.isExpanded ? 1.0 : 0.0

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }

                    ListView {
                        id: timerList
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(contentWidth, parent.width)
                        height: parent.height
                        orientation: ListView.Horizontal
                        spacing: 8
                        clip: true
                        model: timerSectionRect.timerOptions
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: timerSectionRect.isExpanded && contentWidth > width

                        onVisibleChanged: {
                            if (visible && settingsManager) {
                                let currentValue = settingsManager.autoCloseTimerEnabled ? settingsManager.autoCloseTimerInterval : 0
                                let index = -1
                                for (let i = 0; i < timerSectionRect.timerOptions.length; i++) {
                                    if (timerSectionRect.timerOptions[i].value === currentValue) {
                                        index = i
                                        break
                                    }
                                }
                                if (index >= 0) {
                                    Qt.callLater(() => {
                                        timerList.currentIndex = index
                                        timerList.positionViewAtIndex(index, ListView.Center)
                                    })
                                }
                            }
                        }

                        delegate: Rectangle {
                            width: Math.max(timerText.implicitWidth + 24, 80)
                            height: 36
                            radius: 8
                            property bool isCurrent: {
                                if (!settingsManager) return false
                                if (modelData.value === 0) {
                                    return !settingsManager.autoCloseTimerEnabled || settingsManager.autoCloseTimerInterval === 0
                                }
                                return settingsManager.autoCloseTimerEnabled && settingsManager.autoCloseTimerInterval === modelData.value
                            }

                            color: timerMouseArea.containsMouse
                                ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                                : (isCurrent
                                    ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.95) : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                                    : (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15) : Qt.rgba(0.65, 0.55, 0.85, 0.15)))

                            border.width: isCurrent ? 1 : 0
                            border.color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            Text {
                                id: timerText
                                anchors.centerIn: parent
                                text: modelData.label
                                color: isCurrent
                                    ? (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                                    : (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.70))
                                font.pixelSize: 12
                                font.family: "M PLUS 2"
                                font.weight: isCurrent ? Font.Medium : Font.Normal
                            }

                            MouseArea {
                                id: timerMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (settingsManager) {
                                        if (modelData.value === 0) {
                                            settingsManager.autoCloseTimerEnabled = false
                                        } else {
                                            settingsManager.autoCloseTimerEnabled = true
                                            settingsManager.autoCloseTimerInterval = modelData.value
                                        }
                                        settingsManager.saveSettings()
                                    }
                                    timerSectionRect.isExpanded = false
                                    root.resetAutoCloseTimer()
                                }
                            }
                        }

                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            height: 4

                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: gradientSection

        Rectangle {
            width: parent ? parent.width : 420
            height: 64
            color: theme ? theme.surfaceGlass : Qt.rgba(0.15, 0.15, 0.20, 0.5)
            radius: 20
            border.width: 1
            border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "Bar Background Gradient"
                    color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    font.weight: Font.Normal
                    font.letterSpacing: 0.5
                }

                Common.Switch {
                    id: gradientSwitch
                    checked: settingsManager ? settingsManager.barGradientEnabled : true
                    theme: root.theme

                    Connections {
                        target: settingsManager
                        function onBarGradientEnabledChanged() {
                            if (settingsManager) {
                                gradientSwitch.checked = settingsManager.barGradientEnabled
                            }
                        }
                    }

                    onToggled: {
                        if (settingsManager) {
                            settingsManager.barGradientEnabled = checked
                            settingsManager.saveSettings()
                            root.resetAutoCloseTimer()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: animationSection

        Rectangle {
            id: animationSectionRect
            width: parent ? parent.width : 420
            height: animationSectionRect.isExpanded ? 120 : 64
            color: theme ? theme.surfaceGlass : Qt.rgba(0.15, 0.15, 0.20, 0.5)
            radius: 20
            border.width: 1
            border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
            clip: false

            property bool isExpanded: false
            property var animOptions: ["slow", "normal", "fast", "instant"]

            Behavior on height {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                MouseArea {
                    Layout.fillWidth: true
                    Layout.preferredHeight: modeManager.scale(40)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        animationSectionRect.isExpanded = !animationSectionRect.isExpanded
                        root.resetAutoCloseTimer()
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            text: "Animation Speed"
                            color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                            font.pixelSize: 12
                            font.family: "M PLUS 2"
                            font.weight: Font.Normal
                            font.letterSpacing: 0.5
                        }

                        Text {
                            text: {
                                if (!settingsManager) return "..."
                                let speed = settingsManager.animationSpeed
                                return speed.charAt(0).toUpperCase() + speed.slice(1)
                            }
                            color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                            font.pixelSize: 12
                            font.family: "M PLUS 2"
                            font.weight: Font.Medium
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: animationSectionRect.isExpanded ? 44 : 0
                    visible: animationSectionRect.isExpanded
                    opacity: animationSectionRect.isExpanded ? 1.0 : 0.0

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }

                    ListView {
                        id: animList
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(contentWidth, parent.width)
                        height: parent.height
                        orientation: ListView.Horizontal
                        spacing: 8
                        clip: true
                        model: animationSectionRect.animOptions
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: animationSectionRect.isExpanded && contentWidth > width

                        onVisibleChanged: {
                            if (visible && settingsManager) {
                                let index = animationSectionRect.animOptions.indexOf(settingsManager.animationSpeed)
                                if (index >= 0) {
                                    Qt.callLater(() => {
                                        animList.currentIndex = index
                                        animList.positionViewAtIndex(index, ListView.Center)
                                    })
                                }
                            }
                        }

                        delegate: Rectangle {
                            width: Math.max(animText.implicitWidth + 24, 80)
                            height: 36
                            radius: 8
                            property bool isCurrent: settingsManager && settingsManager.animationSpeed === modelData

                            color: animMouseArea.containsMouse
                                ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                                : (isCurrent
                                    ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.95) : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                                    : (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15) : Qt.rgba(0.65, 0.55, 0.85, 0.15)))

                            border.width: isCurrent ? 1 : 0
                            border.color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            Text {
                                id: animText
                                anchors.centerIn: parent
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                color: isCurrent
                                    ? (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                                    : (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.70))
                                font.pixelSize: 12
                                font.family: "M PLUS 2"
                                font.weight: isCurrent ? Font.Medium : Font.Normal
                            }

                            MouseArea {
                                id: animMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (settingsManager) {
                                        settingsManager.animationSpeed = modelData
                                        settingsManager.updateAnimationMultiplier()
                                        settingsManager.saveSettings()
                                    }
                                    animationSectionRect.isExpanded = false
                                    root.resetAutoCloseTimer()
                                }
                            }
                        }

                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            height: 4

                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: listPresetsProcess
        command: [
            "bash",
            Quickshell.shellDir + "/scripts/blur-preset.sh",
            "list"
        ]
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) {
                    listPresetsProcess.output += trimmed + "\n"
                }
            }
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                let lines = listPresetsProcess.output.trim().split("\n").filter(line => line.length > 0)
                root.blurPresets = lines
            } else {
                root.blurPresets = []
            }
            listPresetsProcess.output = ""
            root.isLoadingPresets = false
        }
    }

    Process {
        id: applyPresetProcess
        command: []
        running: false

        stdout: SplitParser {
            onRead: data => {
            }
        }

        stderr: SplitParser {
            onRead: data => {
            }
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                Qt.callLater(() => {
                    getCurrentPreset()
                })
            }
        }
    }

    Process {
        id: getCurrentPresetProcess
        command: [
            "bash",
            Quickshell.shellDir + "/scripts/blur-preset.sh",
            "current"
        ]
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) {
                    getCurrentPresetProcess.output += trimmed
                }
            }
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.currentPreset = getCurrentPresetProcess.output.trim()
            } else {
                root.currentPreset = ""
            }
            getCurrentPresetProcess.output = ""
        }
    }
}
