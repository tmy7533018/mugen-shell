import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../ui" as UI
import "./settings" as Settings

Item {
    id: root

    required property var modeManager
    property var theme
    required property var settingsManager
    required property var blurPresets
    required property string currentPreset
    required property bool isLoadingPresets
    required property var notificationSounds
    required property var timerSounds
    property string soundsDir: ""
    property string timerSoundsDir: ""

    signal applyPreset(string name)
    signal applySound(string name)
    signal applyTimerSound(string name)
    signal editAiConfig()
    signal restartAi()

    readonly property var categories: [
        { id: "appearance", label: "Appearance",   types: ["theme", "gradient", "blur", "animation", "dateFormat"] },
        { id: "sound",      label: "Sound",        types: ["notificationSound", "timerSound"] },
        { id: "timer",      label: "Timer & Lock", types: ["timer", "lockTimer"] },
        { id: "ai",         label: "AI / Yura",    types: ["yuraPersonality", "aiBarModel", "yuraThinking", "yuraPanelSide"] },
        { id: "system",     label: "System",       types: ["battery", "shortcuts"] },
        { id: "reset",      label: "Reset",        types: ["reset"], danger: true }
    ]

    property string selectedCategory: "appearance"

    Rectangle {
        anchors.fill: parent
        color: theme ? theme.surfaceInsetCard : Qt.rgba(0.05, 0.05, 0.08, 0.92)
        radius: 0
        border.width: 0

        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                Qt.quit()
                event.accepted = true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 12

                UI.SvgIcon {
                    Layout.alignment: Qt.AlignVCenter
                    width: 22
                    height: 22
                    source: Quickshell.shellDir + "/assets/icons/settings.svg"
                    color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    text: "Settings"
                    color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    font.pixelSize: 20
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1.5
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Column {
                    id: sidebar
                    width: 150
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    spacing: 4

                    Repeater {
                        model: root.categories
                        delegate: Rectangle {
                            width: sidebar.width
                            height: 36
                            radius: 10
                            property bool selected: root.selectedCategory === modelData.id
                            property bool danger: modelData.danger === true
                            color: selected
                                ? (danger
                                    ? Qt.rgba(0.95, 0.55, 0.65, 0.20)
                                    : (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20) : Qt.rgba(0.65, 0.55, 0.85, 0.20)))
                                : (categoryArea.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.04)
                                    : "transparent")

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 14
                                text: modelData.label
                                color: parent.danger
                                    ? Qt.rgba(0.95, 0.55, 0.65, parent.selected ? 1.0 : 0.78)
                                    : (parent.selected
                                        ? (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95))
                                        : (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)))
                                font.pixelSize: 12
                                font.weight: parent.selected ? Font.Medium : Font.Normal
                                font.family: "M PLUS 2"
                                font.letterSpacing: 0.5
                            }

                            MouseArea {
                                id: categoryArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedCategory = modelData.id
                            }
                        }
                    }
                }

                ListView {
                    id: settingsList
                    anchors.left: sidebar.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 16
                    spacing: 16
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 4

                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                        }
                    }

                    model: ListModel { id: settingsModel }

                    delegate: Loader {
                        width: settingsList.width
                        sourceComponent: {
                            switch (model.type) {
                                case "theme":             return themeSection
                                case "blur":              return blurSection
                                case "timer":             return timerSection
                                case "gradient":          return gradientSection
                                case "battery":           return batterySection
                                case "animation":         return animationSection
                                case "notificationSound": return notificationSoundSection
                                case "timerSound":        return timerSoundSection
                                case "lockTimer":         return lockTimerSection
                                case "dateFormat":        return dateFormatSection
                                case "aiBarModel":        return aiBarModelSection
                                case "yuraPanelSide":     return yuraPanelSideSection
                                case "yuraPersonality":   return yuraPersonalitySection
                                case "yuraThinking":      return yuraThinkingSection
                                case "shortcuts":         return shortcutsSection
                                case "reset":             return resetSection
                                default:                  return null
                            }
                        }
                    }

                    function rebuild() {
                        settingsModel.clear()
                        for (let i = 0; i < root.categories.length; i++) {
                            if (root.categories[i].id === root.selectedCategory) {
                                let types = root.categories[i].types
                                for (let j = 0; j < types.length; j++) {
                                    settingsModel.append({ "type": types[j] })
                                }
                                break
                            }
                        }
                    }

                    Component.onCompleted: rebuild()
                }

                Connections {
                    target: root
                    function onSelectedCategoryChanged() { settingsList.rebuild() }
                }
            }
        }
    }

    Component { id: themeSection; Settings.ThemeSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: blurSection; Settings.BlurSection {
        theme: root.theme
        modeManager: root.modeManager
        presets: root.blurPresets
        currentPreset: root.currentPreset
        isLoadingPresets: root.isLoadingPresets
        onApplyPreset: name => root.applyPreset(name)
    }}
    Component { id: timerSection; Settings.TimerSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: gradientSection; Settings.GradientSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: batterySection; Settings.BatterySection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: animationSection; Settings.AnimationSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: notificationSoundSection; Settings.NotificationSoundSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
        sounds: root.notificationSounds
        folderPath: root.soundsDir
        onApplySound: name => root.applySound(name)
    }}
    Component { id: timerSoundSection; Settings.TimerSoundSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
        sounds: root.timerSounds
        folderPath: root.timerSoundsDir
        onApplySound: name => root.applyTimerSound(name)
    }}
    Component { id: lockTimerSection; Settings.LockTimerSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: dateFormatSection; Settings.DateFormatSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: aiBarModelSection; Settings.AiBarModelSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: yuraPanelSideSection; Settings.YuraPanelSideSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: yuraPersonalitySection; Settings.YuraPersonalitySection {
        theme: root.theme
        modeManager: root.modeManager
        onEditConfig: root.editAiConfig()
        onRestartService: root.restartAi()
    }}
    Component { id: yuraThinkingSection; Settings.YuraThinkingSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: shortcutsSection; Settings.KeyboardShortcutsSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: resetSection; Settings.ResetSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
}
