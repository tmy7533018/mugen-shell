import QtQuick
import Quickshell.Io

QtObject {
    id: wifiManager

    property bool isPowered: true
    property bool isConnected: false
    property string currentSsid: "Not Connected"
    property int signalStrength: 0
    property var availableNetworks: []

    property bool isConnecting: false
    property string connectionError: ""
    property bool isRefreshing: false

    function togglePower() {
        wifiToggleProcess.running = true
    }

    function refreshWifiStatus() {
        wifiStatusProcess.running = true
        wifiPowerStatusProcess.running = true
    }

    function scanNetworks() {
        wifiScanProcess.running = true
    }

    function connectToNetwork(ssid, password) {
        isConnecting = true
        connectionError = ""

        let escapedSsid = ssid.replace(/'/g, "'\\''")
        let escapedPassword = password.replace(/'/g, "'\\''")

        connectToNetworkProcess.ssid = ssid
        connectToNetworkProcess.password = password

        if (password.length > 0) {
            connectToNetworkProcess.command = [
                "bash", "-c",
                "LANG=C nmcli dev wifi connect '" + escapedSsid + "' password '" + escapedPassword + "'"
            ]
        } else {
            connectToNetworkProcess.command = [
                "bash", "-c",
                "LANG=C nmcli dev wifi connect '" + escapedSsid + "'"
            ]
        }

        connectToNetworkProcess.running = true
    }

    function fullRefresh() {
        isRefreshing = true
        refreshWifiStatus()
        scanNetworks()
    }

    property Process wifiStatusProcess: Process {
        command: ["bash", "-c", "LANG=C nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | grep '^yes'"]
        running: false

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => {
                wifiStatusProcess.outputData += data
            }
        }

        onExited: (code, status) => {
            let trimmed = wifiStatusProcess.outputData.trim()

            if (code === 0 && trimmed.length > 0) {
                let parts = trimmed.split(":")

                if (parts.length >= 3 && parts[0] === "yes") {
                    wifiManager.isConnected = true
                    wifiManager.currentSsid = parts[1]
                    wifiManager.signalStrength = parseInt(parts[2]) || 0
                } else {
                    wifiManager.isConnected = false
                    wifiManager.currentSsid = "Not Connected"
                    wifiManager.signalStrength = 0
                }
            } else {
                wifiManager.isConnected = false
                wifiManager.currentSsid = "Not Connected"
                wifiManager.signalStrength = 0
            }

            wifiStatusProcess.outputData = ""
            checkRefreshComplete()
        }

        function checkRefreshComplete() {
            if (!wifiScanProcess.running) {
                wifiManager.isRefreshing = false
            }
        }
    }

    property Process wifiScanProcess: Process {
        command: ["bash", "-c", "LANG=C nmcli -t -f SSID,SIGNAL,SECURITY dev wifi"]
        running: false

        property var networks: []

        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) {
                    let parts = trimmed.split(":")
                    if (parts.length >= 3) {
                        let ssid = parts[0]
                        let signal = parseInt(parts[1]) || 0
                        let secured = parts[2].length > 0

                        if (ssid.length > 0) {
                            wifiScanProcess.networks.push({
                                "ssid": ssid,
                                "signal": signal,
                                "secured": secured
                            })
                        }
                    }
                }
            }
        }

        onExited: (code, status) => {
            let sortedNetworks = wifiScanProcess.networks.sort((a, b) => b.signal - a.signal)
            wifiScanProcess.networks = []

            if (!wifiStatusProcess.running) {
                wifiManager.isRefreshing = false
                wifiManager.availableNetworks = sortedNetworks
            } else {
                wifiManager.availableNetworks = sortedNetworks
            }
        }
    }

    property Process connectToNetworkProcess: Process {
        running: false

        property string ssid: ""
        property string password: ""
        property string outputData: ""
        property string errorData: ""

        stdout: SplitParser {
            onRead: data => {
                connectToNetworkProcess.outputData += data
            }
        }

        stderr: SplitParser {
            onRead: data => {
                connectToNetworkProcess.errorData += data
            }
        }

        onExited: (code, status) => {
            wifiManager.isConnecting = false

            if (code === 0) {
                wifiManager.connectionError = ""
                wifiManager.refreshWifiStatus()
            } else {
                let errorMsg = connectToNetworkProcess.errorData.toLowerCase()

                if (errorMsg.includes("secret") || errorMsg.includes("password") || errorMsg.includes("psk")) {
                    wifiManager.connectionError = "Incorrect password"
                } else if (errorMsg.includes("timeout") || errorMsg.includes("no reply")) {
                    wifiManager.connectionError = "Connection timeout"
                } else if (errorMsg.includes("not found")) {
                    wifiManager.connectionError = "Network not found"
                } else {
                    wifiManager.connectionError = "Connection failed"
                }
            }

            connectToNetworkProcess.outputData = ""
            connectToNetworkProcess.errorData = ""
        }
    }

    property Process wifiPowerStatusProcess: Process {
        command: ["bash", "-c", "nmcli radio wifi | grep -q 'enabled' && echo 'yes' || echo 'no'"]
        running: false

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => {
                wifiPowerStatusProcess.outputData += data
            }
        }

        onExited: (code, status) => {
            let trimmed = wifiPowerStatusProcess.outputData.trim().toLowerCase()
            let wasPowered = wifiManager.isPowered
            wifiManager.isPowered = (trimmed === "yes")
            wifiPowerStatusProcess.outputData = ""

            if (!wifiManager.isPowered) {
                wifiManager.availableNetworks = []
                wifiManager.isConnected = false
                wifiManager.currentSsid = "Not Connected"
                wifiManager.signalStrength = 0
            } else if (!wasPowered) {
                // WiFi just turned on; wait briefly before fetching state
                Qt.callLater(() => {
                    fullRefresh()
                })
            }
        }
    }

    property Process wifiToggleProcess: Process {
        command: ["bash", "-c", wifiManager.isPowered ? "nmcli radio wifi off" : "nmcli radio wifi on"]
        running: false

        onExited: (code, status) => {
            // state refresh is triggered in wifiPowerStatusProcess.onExited
            wifiPowerStatusProcess.running = true
        }
    }

    property Process dbusMonitor: Process {
        command: [
            "dbus-monitor",
            "--system",
            "type='signal',sender='org.freedesktop.NetworkManager'"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                wifiDebounceTimer.restart()
            }
        }

        stderr: SplitParser {
            onRead: data => {
            }
        }
    }

    property Timer wifiDebounceTimer: Timer {
        interval: 200
        repeat: false
        onTriggered: {
            if (!wifiStatusProcess.running && !wifiPowerStatusProcess.running) {
                refreshWifiStatus()
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            refreshWifiStatus()
        })
    }

    Component.onDestruction: {
        if (dbusMonitor.running) {
            dbusMonitor.running = false
        }
    }
}
