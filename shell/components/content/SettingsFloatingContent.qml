import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

    signal applyPreset(string name)
    signal applySound(string name)
    signal applyTimerSound(string name)

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
                spacing: 10

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "Settings"
                    color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    font.pixelSize: 20
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1.5
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: resetText.implicitWidth + 24
                    Layout.preferredHeight: 28
                    color: resetMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    border.width: 1
                    border.color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.3) : Qt.rgba(0.65, 0.55, 0.85, 0.3)
                    radius: 14

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: resetText
                        anchors.centerIn: parent
                        text: "Reset"
                        color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.5
                    }

                    MouseArea {
                        id: resetMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (settingsManager) settingsManager.resetToDefault()
                        }
                    }
                }
            }

            ListView {
                id: settingsList
                Layout.fillWidth: true
                Layout.fillHeight: true
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

                model: ListModel {
                    id: settingsModel
                }

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
                            case "shortcuts":         return shortcutsSection
                            default:                  return null
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
                    settingsModel.append({ "type": "timerSound" })
                    settingsModel.append({ "type": "lockTimer" })
                    settingsModel.append({ "type": "dateFormat" })
                    settingsModel.append({ "type": "shortcuts" })
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
        onApplySound: name => root.applySound(name)
    }}
    Component { id: timerSoundSection; Settings.TimerSoundSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
        sounds: root.notificationSounds
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
    Component { id: shortcutsSection; Settings.KeyboardShortcutsSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
}
