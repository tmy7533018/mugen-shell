import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../common" as Common
import "./settings" as Settings

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

    function openAiConfig() {
        let cfgHome = Quickshell.env("XDG_CONFIG_HOME")
        if (!cfgHome || cfgHome === "") {
            cfgHome = Quickshell.env("HOME") + "/.config"
        }
        openAiConfigProcess.command = ["xdg-open", cfgHome + "/mugen-ai/config.toml"]
        openAiConfigProcess.running = true
    }

    function restartAi() {
        restartAiProcess.command = ["systemctl", "--user", "restart", "mugen-ai.service"]
        restartAiProcess.running = true
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
                            case "aiConfig": return aiConfigSection
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
                    settingsModel.append({ "type": "aiConfig" })
                }
            }
        }
    }

    Component {
        id: themeSection
        Settings.ThemeSection {
            theme: root.theme
            modeManager: root.modeManager
        }
    }

    Component {
        id: blurSection
        Settings.BlurSection {
            theme: root.theme
            modeManager: root.modeManager
            presets: root.blurPresets
            currentPreset: root.currentPreset
            isLoadingPresets: root.isLoadingPresets
            onApplyPreset: name => root.applyBlurPreset(name)
        }
    }

    Component {
        id: timerSection
        Settings.TimerSection {
            theme: root.theme
            modeManager: root.modeManager
            settingsManager: root.settingsManager
        }
    }

    Component {
        id: gradientSection
        Settings.GradientSection {
            theme: root.theme
            modeManager: root.modeManager
            settingsManager: root.settingsManager
        }
    }

    Component {
        id: batterySection
        Settings.BatterySection {
            theme: root.theme
            modeManager: root.modeManager
            settingsManager: root.settingsManager
        }
    }

    Component {
        id: animationSection
        Settings.AnimationSection {
            theme: root.theme
            modeManager: root.modeManager
            settingsManager: root.settingsManager
        }
    }

    Component {
        id: notificationSoundSection
        Settings.NotificationSoundSection {
            theme: root.theme
            modeManager: root.modeManager
            settingsManager: root.settingsManager
            sounds: root.notificationSounds
            onApplySound: name => root.applyNotificationSound(name)
        }
    }

    Component {
        id: lockTimerSection
        Settings.LockTimerSection {
            theme: root.theme
            modeManager: root.modeManager
            settingsManager: root.settingsManager
        }
    }

    Component {
        id: aiConfigSection
        Settings.AiConfigSection {
            theme: root.theme
            modeManager: root.modeManager
            onEditConfig: root.openAiConfig()
            onRestartService: root.restartAi()
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

    Process {
        id: openAiConfigProcess
        command: []
        running: false
    }

    Process {
        id: restartAiProcess
        command: []
        running: false
    }
}
