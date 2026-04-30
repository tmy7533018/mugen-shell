import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../common" as Common

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

    property var notificationSounds: ["None"]

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

    function loadNotificationSounds() {
        listSoundsProcess.running = true
    }

    function applyNotificationSound(name) {
        if (settingsManager) {
            settingsManager.notificationSound = name
            settingsManager.saveSettings()
        }
        if (name !== "None") {
            previewSoundProcess.command = [
                "paplay",
                Quickshell.shellDir + "/assets/sounds/" + name
            ]
            previewSoundProcess.running = true
        }
        root.resetAutoCloseTimer()
    }

    function applyLockTimer(minutes) {
        applyLockTimerProcess.command = [
            "bash",
            Quickshell.shellDir + "/scripts/lock-timer.sh",
            String(minutes)
        ]
        applyLockTimerProcess.running = true
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("settings", root)
            if (modeManager.isMode("settings")) {
                loadBlurPresets()
                loadNotificationSounds()
            }
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("settings")) {
                loadBlurPresets()
                loadNotificationSounds()
            }
        }
    }

    Connections {
        target: settingsManager
        function onLockTimerMinutesChanged() {
            // Fires on slider release and on Reset to Default. Keeps
            // hypridle.conf in sync with the persisted value either way.
            root.applyLockTimer(settingsManager.lockTimerMinutes)
        }
    }

    function resetAutoCloseTimer() {
        if (modeManager.isMode("settings")) modeManager.bump()
    }

    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("settings") && settingsLayer.visible
        visible: enabled
        hoverEnabled: true

        onClicked: {
            modeManager.closeAllModes()
        }

        onPositionChanged: {
            if (modeManager.isMode("settings")) {
                modeManager.bump()
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
                modeManager.bump()
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
                            case "battery": return batterySection
                            case "animation": return animationSection
                            case "notificationSound": return notificationSoundSection
                            case "lockTimer": return lockTimerSection
                            default: return null
                        }
                    }
                }

                Component.onCompleted: {
                    settingsModel.append({ "type": "theme" })
                    settingsModel.append({ "type": "blur" })
                    settingsModel.append({ "type": "timer" })
                    settingsModel.append({ "type": "gradient" })
                    settingsModel.append({ "type": "battery" })
                    settingsModel.append({ "type": "animation" })
                    settingsModel.append({ "type": "notificationSound" })
                    settingsModel.append({ "type": "lockTimer" })
                }
            }
        }
    }

    Component {
        id: themeSection

        Rectangle {
            width: parent ? parent.width : 420
            height: 64
            color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
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
            height: blurSectionRect.isExpanded ? 64 + Math.min(root.blurPresets.length, 6) * 36 + 12 : 64
            color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
            radius: 20
            border.width: 1
            border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
            clip: true

            property bool isExpanded: false

            Behavior on height {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            MouseArea {
                id: blurHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 64
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                TapHandler {
                    onTapped: {
                        blurSectionRect.isExpanded = !blurSectionRect.isExpanded
                        root.resetAutoCloseTimer()
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
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
                        text: root.isLoadingPresets ? "Loading…"
                            : (root.currentPreset || "Select preset")
                        color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.pixelSize: 12
                        font.family: "M PLUS 2"
                        font.weight: Font.Medium
                    }

                    Text {
                        text: blurSectionRect.isExpanded ? "▴" : "▾"
                        color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                        font.pixelSize: 12
                        font.family: "M PLUS 2"
                    }
                }
            }

            ListView {
                id: presetList
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: blurHeader.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.bottomMargin: 12
                clip: true
                model: root.blurPresets
                visible: blurSectionRect.isExpanded
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: presetList.width
                    height: 36
                    radius: 8
                    property bool isCurrent: modelData === root.currentPreset

                    color: presetMouseArea.containsMouse
                        ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                        : (isCurrent
                            ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4))
                            : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        text: modelData
                        color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.pixelSize: 12
                        font.family: "M PLUS 2"
                        font.weight: isCurrent ? Font.Medium : Font.Normal
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 12
                        text: "✓"
                        visible: isCurrent
                        color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                        font.pixelSize: 12
                        font.family: "M PLUS 2"
                    }

                    MouseArea {
                        id: presetMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: {
                            root.applyBlurPreset(modelData)
                            blurSectionRect.isExpanded = false
                            root.resetAutoCloseTimer()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: timerSection

        Rectangle {
            width: parent ? parent.width : 420
            height: 64
            color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
            radius: 20
            border.width: 1
            border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
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

                Item {
                    id: timerSlider
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 24

                    property real from: 0
                    property real to: 30
                    property real stepSize: 1
                    property real value: settingsManager ? Math.round(settingsManager.autoCloseTimerInterval / 1000) : 5

                    function valueAt(x) {
                        const w = Math.max(1, width)
                        const ratio = Math.max(0, Math.min(1, x / w))
                        const raw = from + ratio * (to - from)
                        return Math.round(raw / stepSize) * stepSize
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.15)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * (timerSlider.value - timerSlider.from) / (timerSlider.to - timerSlider.from)
                            radius: parent.radius
                            color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                        }
                    }

                    Rectangle {
                        x: ((timerSlider.value - timerSlider.from) / (timerSlider.to - timerSlider.from)) * (timerSlider.width - width)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, timerMouseArea.pressed ? 1.0 : 0.95) : Qt.rgba(0.65, 0.55, 0.85, 0.95)
                        border.width: 1
                        border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
                    }

                    MouseArea {
                        id: timerMouseArea
                        anchors.fill: parent
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true

                        onPressed: (mouse) => {
                            timerSlider.value = timerSlider.valueAt(mouse.x)
                            root.resetAutoCloseTimer()
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed) timerSlider.value = timerSlider.valueAt(mouse.x)
                        }
                        onReleased: {
                            if (settingsManager) {
                                settingsManager.autoCloseTimerInterval = Math.round(timerSlider.value) * 1000
                                settingsManager.saveSettings()
                            }
                            root.resetAutoCloseTimer()
                        }
                    }
                }

                Text {
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                    text: timerSlider.value === 0 ? "Off" : Math.round(timerSlider.value) + "s"
                    color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    font.weight: Font.Medium
                }
            }
        }
    }

    Component {
        id: gradientSection

        Rectangle {
            width: parent ? parent.width : 420
            height: 64
            color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
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
        id: batterySection

        Rectangle {
            width: parent ? parent.width : 420
            height: 64
            color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
            radius: 20
            border.width: 1
            border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "Battery Indicator"
                    color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    font.weight: Font.Normal
                    font.letterSpacing: 0.5
                }

                Common.Switch {
                    id: batterySwitch
                    checked: settingsManager ? settingsManager.batteryIndicatorEnabled : false
                    theme: root.theme

                    Connections {
                        target: settingsManager
                        function onBatteryIndicatorEnabledChanged() {
                            if (settingsManager) {
                                batterySwitch.checked = settingsManager.batteryIndicatorEnabled
                            }
                        }
                    }

                    onToggled: {
                        if (settingsManager) {
                            settingsManager.batteryIndicatorEnabled = checked
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
            color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
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
                    preventStealing: true

                    TapHandler {
                        onTapped: {
                            animationSectionRect.isExpanded = !animationSectionRect.isExpanded
                            root.resetAutoCloseTimer()
                        }
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
                                preventStealing: true
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

    Component {
        id: notificationSoundSection

        Rectangle {
            id: soundSectionRect
            width: parent ? parent.width : 420
            height: soundSectionRect.isExpanded ? 64 + Math.min(root.notificationSounds.length, 6) * 36 + 12 : 64
            color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
            radius: 20
            border.width: 1
            border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
            clip: true

            property bool isExpanded: false

            Behavior on height {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            MouseArea {
                id: soundHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 64
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                TapHandler {
                    onTapped: {
                        soundSectionRect.isExpanded = !soundSectionRect.isExpanded
                        root.resetAutoCloseTimer()
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: "Notification Sound"
                        color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                        font.pixelSize: 12
                        font.family: "M PLUS 2"
                        font.weight: Font.Normal
                        font.letterSpacing: 0.5
                    }

                    Text {
                        text: settingsManager ? settingsManager.notificationSound : "None"
                        color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.pixelSize: 12
                        font.family: "M PLUS 2"
                        font.weight: Font.Medium
                    }

                    Text {
                        text: soundSectionRect.isExpanded ? "▴" : "▾"
                        color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                        font.pixelSize: 12
                        font.family: "M PLUS 2"
                    }
                }
            }

            ListView {
                id: soundList
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: soundHeader.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.bottomMargin: 12
                clip: true
                model: root.notificationSounds
                visible: soundSectionRect.isExpanded
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: soundList.width
                    height: 36
                    radius: 8
                    property bool isCurrent: settingsManager && modelData === settingsManager.notificationSound

                    color: soundMouseArea.containsMouse
                        ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                        : (isCurrent
                            ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4))
                            : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        text: modelData
                        color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.pixelSize: 12
                        font.family: "M PLUS 2"
                        font.weight: isCurrent ? Font.Medium : Font.Normal
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 12
                        text: "✓"
                        visible: isCurrent
                        color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                        font.pixelSize: 12
                        font.family: "M PLUS 2"
                    }

                    MouseArea {
                        id: soundMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: {
                            root.applyNotificationSound(modelData)
                            soundSectionRect.isExpanded = false
                            root.resetAutoCloseTimer()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: lockTimerSection

        Rectangle {
            width: parent ? parent.width : 420
            height: 64
            color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
            radius: 20
            border.width: 1
            border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "Screen Lock Timer"
                    color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    font.weight: Font.Normal
                    font.letterSpacing: 0.5
                }

                Item {
                    id: lockSlider
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 24

                    property real from: 1
                    property real to: 30
                    property real stepSize: 1
                    property real value: settingsManager ? settingsManager.lockTimerMinutes : 10

                    function valueAt(x) {
                        const w = Math.max(1, width)
                        const ratio = Math.max(0, Math.min(1, x / w))
                        const raw = from + ratio * (to - from)
                        return Math.round(raw / stepSize) * stepSize
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.15)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * (lockSlider.value - lockSlider.from) / (lockSlider.to - lockSlider.from)
                            radius: parent.radius
                            color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                        }
                    }

                    Rectangle {
                        x: ((lockSlider.value - lockSlider.from) / (lockSlider.to - lockSlider.from)) * (lockSlider.width - width)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, lockMouseArea.pressed ? 1.0 : 0.95) : Qt.rgba(0.65, 0.55, 0.85, 0.95)
                        border.width: 1
                        border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
                    }

                    MouseArea {
                        id: lockMouseArea
                        anchors.fill: parent
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true

                        onPressed: (mouse) => {
                            lockSlider.value = lockSlider.valueAt(mouse.x)
                            root.resetAutoCloseTimer()
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed) lockSlider.value = lockSlider.valueAt(mouse.x)
                        }
                        onReleased: {
                            if (settingsManager) {
                                settingsManager.lockTimerMinutes = Math.round(lockSlider.value)
                                settingsManager.saveSettings()
                            }
                            root.resetAutoCloseTimer()
                        }
                    }
                }

                Text {
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(lockSlider.value) + "m"
                    color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    font.weight: Font.Medium
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

    Process {
        id: listSoundsProcess
        command: [
            "bash", "-c",
            "find '" + Quickshell.shellDir + "/assets/sounds' -maxdepth 1 -type f \\( -iname '*.wav' -o -iname '*.ogg' -o -iname '*.oga' -o -iname '*.mp3' -o -iname '*.flac' \\) -printf '%f\\n' | sort"
        ]
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) {
                    listSoundsProcess.output += trimmed + "\n"
                }
            }
        }

        onExited: (exitCode) => {
            let files = ["None"]
            if (exitCode === 0) {
                let lines = listSoundsProcess.output.trim().split("\n").filter(l => l.length > 0)
                files = files.concat(lines)
            }
            root.notificationSounds = files
            listSoundsProcess.output = ""
        }
    }

    Process {
        id: previewSoundProcess
        command: []
        running: false
    }

    Process {
        id: applyLockTimerProcess
        command: []
        running: false
    }
}
