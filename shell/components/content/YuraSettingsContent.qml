import QtQuick
import Quickshell
import "./settings" as Settings

Item {
    id: root

    required property var modeManager
    property var theme
    required property var settingsManager

    signal editAiConfig()
    signal restartAi()

    readonly property var categories: [
        { id: "model",    label: "Model",       types: ["yuraProvider", "aiBarModel", "yuraPersonality"] },
        { id: "voice",    label: "Voice",       types: ["voice"] },
        { id: "tools",    label: "Tools & MCP", types: ["yuraToolCategories", "yuraMcp", "yuraMcpExpose", "yuraAppLaunch"] },
        { id: "memory",   label: "Memory",      types: ["yuraMemory", "yuraHistory"] },
        { id: "panel",    label: "Panel",       types: ["yuraPanelSide", "yuraUi", "yuraThinking"] },
        { id: "advanced", label: "Advanced",    types: ["yuraAdvanced"] }
    ]

    function sectionFor(type) {
        switch (type) {
            case "yuraProvider":       return yuraProviderSection
            case "aiBarModel":         return aiBarModelSection
            case "yuraPersonality":    return yuraPersonalitySection
            case "voice":              return voiceSection
            case "yuraToolCategories": return yuraToolCategoriesSection
            case "yuraMcp":            return yuraMcpSection
            case "yuraMcpExpose":      return yuraMcpExposeSection
            case "yuraAppLaunch":      return yuraAppLaunchSection
            case "yuraMemory":         return yuraMemorySection
            case "yuraHistory":        return yuraHistorySection
            case "yuraPanelSide":      return yuraPanelSideSection
            case "yuraUi":             return yuraUiSection
            case "yuraThinking":       return yuraThinkingSection
            case "yuraAdvanced":       return yuraAdvancedSection
            default:                   return null
        }
    }

    Settings.SettingsFrame {
        anchors.fill: parent
        theme: root.theme
        categories: root.categories
        title: "Yura"
        iconSource: Quickshell.shellDir + "/assets/icons/ai.svg"
        resolveSection: root.sectionFor
    }

    Component { id: yuraProviderSection; Settings.YuraProviderSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: aiBarModelSection; Settings.AiBarModelSection {
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
    Component { id: voiceSection; Settings.VoiceSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: yuraToolCategoriesSection; Settings.YuraToolCategoriesSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: yuraMcpSection; Settings.YuraMcpSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: yuraMcpExposeSection; Settings.YuraMcpExposeSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: yuraAppLaunchSection; Settings.YuraAppLaunchSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: yuraMemorySection; Settings.YuraMemorySection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: yuraHistorySection; Settings.YuraHistorySection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: yuraPanelSideSection; Settings.YuraPanelSideSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: yuraUiSection; Settings.YuraUiSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: yuraThinkingSection; Settings.YuraThinkingSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: yuraAdvancedSection; Settings.YuraAdvancedSection {
        theme: root.theme
        modeManager: root.modeManager
        onEditConfig: root.editAiConfig()
        onRestartService: root.restartAi()
    }}
}
