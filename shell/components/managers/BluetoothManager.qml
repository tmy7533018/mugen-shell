import QtQuick
import Quickshell.Io

QtObject {
    id: bluetoothManager

    property bool isPowered: false
    property bool isScanning: false
    property var pairedDevices: []
    property var availableDevices: []
    property var deviceNameQueue: []
    property bool isConnecting: false
    property bool isPairing: false
    property string connectionError: ""
    property string pairingError: ""

    readonly property bool hasConnectedDevices: {
        if (!pairedDevices || pairedDevices.length === 0) return false
        return pairedDevices.some(device => device.connected)
    }

    readonly property bool isTogglingPower: bluetoothToggleProcess.running

    function togglePower() {
        bluetoothToggleProcess.running = true
    }

    function startScan() {
        isScanning = true
        availableDevices = []
        bluetoothScanProcess.devices = []
        bluetoothScanProcess.deviceMap = {}

        if (bluetoothScanProcess.running) {
            bluetoothScanOffProcess.running = true
            Qt.callLater(() => {
                bluetoothScanProcess.running = true
                scanTimeoutTimer.start()
            })
        } else {
            bluetoothScanProcess.running = true
            scanTimeoutTimer.start()
        }
    }

    property Timer scanTimeoutTimer: Timer {
        interval: 10000
        running: false
        repeat: false
        onTriggered: {
            if (bluetoothManager.isScanning) {
                bluetoothScanProcess.running = false
                Qt.callLater(() => {
                    bluetoothScanOffProcess.running = true
                })
            }
        }
    }

    function refreshPairedDevices() {
        pairedDevicesProcess.devices = []
        pairedDevicesProcess.allOutput = ""
        pairedDevicesProcess.running = true
    }

    function toggleDeviceConnection(deviceAddress, deviceName, isCurrentlyConnected) {
        isConnecting = true
        connectionError = ""

        let escapedAddress = deviceAddress.replace(/'/g, "'\\''")
        deviceConnectProcess.deviceAddress = deviceAddress
        deviceConnectProcess.deviceName = deviceName

        if (isCurrentlyConnected) {
            deviceConnectProcess.command = ["bash", "-c", "bluetoothctl disconnect '" + escapedAddress + "'"]
        } else {
            deviceConnectProcess.command = ["bash", "-c", "bluetoothctl connect '" + escapedAddress + "'"]
        }
        deviceConnectProcess.running = true
    }

    function pairDevice(deviceAddress, deviceName) {
        isPairing = true
        pairingError = ""

        let escapedAddress = deviceAddress.replace(/'/g, "'\\''")
        devicePairProcess.deviceAddress = deviceAddress
        devicePairProcess.deviceName = deviceName
        // A device wanting passkey confirmation leaves bluetoothctl on stdin, and nothing else clears isPairing.
        devicePairProcess.command = ["bash", "-c", "timeout 60 bluetoothctl pair '" + escapedAddress + "'"]
        devicePairProcess.running = true
    }

    function refreshStatus() {
        bluetoothStatusProcess.running = true
    }

    property bool rssiPending: false

    // bluetoothctl reports it as "RSSI: 0xffffffc3 (-61)", older builds as "RSSI: -61".
    function applyRssi(address, line) {
        const m = line.match(/RSSI:\s*(?:0x[0-9a-fA-F]+\s*\()?\s*(-?\d+)/)
        if (!m) return
        const value = parseInt(m[1], 10)
        for (const dev of availableDevices) {
            if (dev.address !== address || dev.rssi === value) continue
            dev.rssi = value
            rssiPending = true
            return
        }
    }

    function applyPairedName(deviceAddress) {
        let pairedDevice = pairedDevices.find(dev => dev.address === deviceAddress)
        if (!pairedDevice || !pairedDevice.name || pairedDevice.name.length === 0) return false

        for (let i = 0; i < availableDevices.length; i++) {
            if (availableDevices[i].address === deviceAddress) {
                availableDevices[i].name = pairedDevice.name
                availableDevices = availableDevices.slice()
                return true
            }
        }
        return false
    }

    function fetchDeviceName(deviceAddress) {
        if (applyPairedName(deviceAddress)) return

        // The reply is matched by deviceAddress, so overwriting it mid-flight files device A's name under B.
        if (deviceNameProcess.running) {
            if (!deviceNameQueue.includes(deviceAddress)) {
                deviceNameQueue = deviceNameQueue.concat([deviceAddress])
            }
            return
        }
        startDeviceNameFetch(deviceAddress)
    }

    function fetchNextQueuedDeviceName() {
        while (deviceNameQueue.length > 0) {
            let next = deviceNameQueue[0]
            deviceNameQueue = deviceNameQueue.slice(1)
            if (applyPairedName(next)) continue
            startDeviceNameFetch(next)
            return
        }
    }

    function startDeviceNameFetch(deviceAddress) {
        let escapedAddress = deviceAddress.replace(/'/g, "'\\''")
        deviceNameProcess.deviceAddress = deviceAddress
        deviceNameProcess.command = ["bash", "-c", "bluetoothctl info '" + escapedAddress + "' 2>/dev/null | grep -E '^\\s*(Alias|Name):' | sed -E 's/^\\s*(Alias|Name):\\s*//' | head -1"]
        deviceNameProcess.running = true
    }

    function fetchDeviceNamesSequentially(addresses, index) {
        if (index >= addresses.length) return

        fetchDeviceName(addresses[index])

        deviceNameFetchTimer.addresses = addresses
        deviceNameFetchTimer.currentIndex = index + 1
        deviceNameFetchTimer.start()
    }

    property Timer deviceNameFetchTimer: Timer {
        interval: 300
        running: false
        repeat: false

        property var addresses: []
        property int currentIndex: 0

        onTriggered: {
            if (currentIndex < addresses.length) {
                bluetoothManager.fetchDeviceName(addresses[currentIndex])
                currentIndex++
                if (currentIndex < addresses.length) {
                    start()
                }
            }
        }
    }

    property Process bluetoothStatusProcess: Process {
        command: ["bash", "-c", "bluetoothctl show | grep 'Powered:' | awk '{print $2}'"]
        running: false

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => {
                bluetoothStatusProcess.outputData += data
            }
        }

        onExited: (code, status) => {
            let trimmed = bluetoothStatusProcess.outputData.trim().toLowerCase()
            bluetoothManager.isPowered = (trimmed === "yes")
            bluetoothStatusProcess.outputData = ""

            if (bluetoothManager.isPowered) {
                bluetoothManager.refreshPairedDevices()
            } else {
                bluetoothManager.pairedDevices = []
            }
        }
    }

    property Process bluetoothToggleProcess: Process {
        command: ["bash", "-c", bluetoothManager.isPowered
            ? "bluetoothctl power off"
            : "rfkill unblock bluetooth && bluetoothctl power on"]
        running: false

        onExited: (code, status) => {
            bluetoothStatusProcess.running = true
        }
    }

    property Process dbusMonitor: Process {
        command: [
            "dbus-monitor",
            "--system",
            "type='signal',sender='org.bluez'"
        ]
        running: !bluetoothManager.monitorRestartTimer.running

        stdout: SplitParser {
            onRead: data => {
                bluetoothDebounceTimer.restart()
            }
        }

        // The stream ends when the process does, so this is where a dead monitor shows up.
        stderr: StdioCollector {
            onStreamFinished: bluetoothManager.monitorRestartTimer.restart()
        }
    }

    // A bus hiccup would otherwise leave the Bluetooth state frozen until the panel is reopened.
    property Timer monitorRestartTimer: Timer {
        interval: 2000
    }

    property Timer bluetoothDebounceTimer: Timer {
        interval: 200
        repeat: false
        onTriggered: {
            if (!bluetoothStatusProcess.running && !pairedDevicesProcess.running) {
                refreshStatus()
                if (bluetoothManager.isPowered) {
                    refreshPairedDevices()
                }
            }
        }
    }

    property Process pairedDevicesProcess: Process {
        command: ["bash", "-c", "bluetoothctl devices | while read dev; do if [ -n \"$dev\" ]; then addr=$(echo $dev | awk '{print $2}'); name=$(echo $dev | cut -d' ' -f3-); connected=$(bluetoothctl info $addr 2>/dev/null | grep -q 'Connected: yes' && echo 'true' || echo 'false'); printf \"%s|%s|%s\\n\" \"$name\" \"$addr\" \"$connected\"; fi; done"]
        running: false

        property var devices: []
        property string allOutput: ""

        stdout: SplitParser {
            onRead: data => {
                pairedDevicesProcess.allOutput += data
            }
        }

        onExited: (code, status) => {
            pairedDevicesProcess.devices = []

            let trimmedOutput = pairedDevicesProcess.allOutput.trim()
            if (trimmedOutput.length === 0) {
                bluetoothManager.pairedDevices = []
            } else {
                let allLines = trimmedOutput.split('\n')
                for (let line of allLines) {
                    let trimmed = line.trim()
                    if (trimmed.length > 0) {
                        let parts = trimmed.split("|")
                        if (parts.length >= 3) {
                            let name = parts[0].trim()
                            let address = parts[1].trim()
                            let connected = parts[2].trim()

                            if (address.match(/^[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}$/)) {
                                pairedDevicesProcess.devices.push({
                                    "name": name,
                                    "address": address,
                                    "connected": connected === "true"
                                })
                            }
                        }
                    }
                }

                bluetoothManager.pairedDevices = pairedDevicesProcess.devices.slice()
            }

            // The nearby list's paired flag is only correct once this list has landed.
            bluetoothManager.refreshAvailableDevices()

            pairedDevicesProcess.devices = []
            pairedDevicesProcess.allOutput = ""
        }
    }

    property Process bluetoothScanProcess: Process {
        // One process, not a pipeline: stopping this only signals its direct child.
        command: ["stdbuf", "-oL", "-eL", "bluetoothctl", "--timeout", "10", "scan", "on"]
        running: false

        property var devices: []
        property var deviceMap: ({})
        property string allOutput: ""

        function parseScanLine(line) {
            let cleaned = line.replace(/\u001b\[[0-9;]*m/g, "")
            let trimmed = cleaned.trim()
            if (trimmed.length === 0) return false

            trimmed = trimmed.replace(/\[bluetoothctl\]>\s*$/, "")
            if (trimmed.length === 0) return false

            let match = trimmed.match(/\[(NEW|CHG)\]\s+Device\s+([0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5})(?:\s+(.+))?/i)
            if (match && match.length >= 3) {
                let address = match[2]
                let name = match[3] ? match[3].trim() : ""

                name = name.replace(/\[bluetoothctl\]>\s*$/, "").trim()

                if (name.includes("RSSI:")) {
                    name = name.split("RSSI:")[0].trim()
                }

                if (!bluetoothScanProcess.deviceMap[address]) {
                    let isPaired = bluetoothManager.pairedDevices.some(dev => dev.address === address)

                    let deviceName = name
                    if (isPaired) {
                        let pairedDevice = bluetoothManager.pairedDevices.find(dev => dev.address === address)
                        if (pairedDevice && pairedDevice.name) {
                            deviceName = pairedDevice.name
                        }
                    }

                    if (deviceName && deviceName.match(/^[0-9A-Fa-f]{2}(?:[:-][0-9A-Fa-f]{2}){5}$/)) {
                        deviceName = ""
                    }

                    bluetoothScanProcess.deviceMap[address] = true
                    bluetoothScanProcess.devices.push({
                        "name": deviceName || address,
                        "address": address,
                        "paired": isPaired,
                        "rssi": 0
                    })

                    bluetoothManager.availableDevices = bluetoothScanProcess.devices.slice()

                    if (!deviceName || deviceName === address || deviceName.match(/^[0-9A-Fa-f]{2}(?:[:-][0-9A-Fa-f]{2}){5}$/)) {
                        Qt.callLater(() => {
                            bluetoothManager.fetchDeviceName(address)
                        })
                    }
                }
                bluetoothManager.applyRssi(address, trimmed)
                return true
            }
            return false
        }


        stdout: SplitParser {
            onRead: data => {
                bluetoothScanProcess.allOutput += data
                let lines = data.split('\n')
                for (let line of lines) {
                    bluetoothScanProcess.parseScanLine(line)
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                bluetoothScanProcess.allOutput += data
                // bluetoothctl often outputs to stderr
                let lines = data.split('\n')
                for (let line of lines) {
                    bluetoothScanProcess.parseScanLine(line)
                }
            }
        }

        onExited: (code, status) => {
            bluetoothScanOffProcess.running = true
        }
    }

    // Signal updates land per device per second, and each republish rebuilds the list.
    property Timer rssiPublishTimer: Timer {
        interval: 700
        repeat: true
        running: bluetoothManager.isScanning
        onTriggered: {
            if (!bluetoothManager.rssiPending) return
            bluetoothManager.rssiPending = false
            bluetoothManager.availableDevices = bluetoothManager.availableDevices.slice()
        }
    }

    property Process bluetoothScanOffProcess: Process {
        command: ["bash", "-c", "bluetoothctl scan off 2>&1"]
        running: false

        property string outputData: ""
        property string errorData: ""

        stdout: SplitParser {
            onRead: data => {
                bluetoothScanOffProcess.outputData += data
            }
        }

        stderr: SplitParser {
            onRead: data => {
                bluetoothScanOffProcess.errorData += data
            }
        }

        onExited: (code, status) => {
            // Both the timeout and the scan process's own exit ask for scan off; the later run has an empty list.
            if (!bluetoothManager.isScanning) return
            bluetoothManager.isScanning = false
            bluetoothManager.availableDevices = bluetoothScanProcess.devices.slice()
            if (bluetoothManager.availableDevices.length > 0) {
                let devicesToFetch = []
                for (let i = 0; i < bluetoothManager.availableDevices.length; i++) {
                    let device = bluetoothManager.availableDevices[i]
                    if (!device.name || device.name === device.address || device.name.match(/^[0-9A-Fa-f]{2}(?:[:-][0-9A-Fa-f]{2}){5}$/)) {
                        devicesToFetch.push(device.address)
                    }
                }

                if (devicesToFetch.length > 0) {
                    bluetoothManager.fetchDeviceNamesSequentially(devicesToFetch, 0)
                }
            }
            bluetoothScanProcess.devices = []
            bluetoothScanProcess.deviceMap = {}
            bluetoothScanProcess.allOutput = ""
            bluetoothManager.refreshPairedDevices()
        }
    }

    property Process deviceConnectProcess: Process {
        running: false

        property string deviceAddress: ""
        property string deviceName: ""
        property string outputData: ""
        property string errorData: ""

        stdout: SplitParser {
            onRead: data => {
                deviceConnectProcess.outputData += data
            }
        }

        stderr: SplitParser {
            onRead: data => {
                deviceConnectProcess.errorData += data
            }
        }

        onExited: (code, status) => {
            bluetoothManager.isConnecting = false

            if (code === 0) {
                bluetoothManager.connectionError = ""
                bluetoothManager.refreshPairedDevices()
            } else {
                let errorMsg = (deviceConnectProcess.errorData + deviceConnectProcess.outputData).toLowerCase()

                if (errorMsg.includes("not available") || errorMsg.includes("not found")) {
                    bluetoothManager.connectionError = "Device not available"
                } else if (errorMsg.includes("not paired")) {
                    bluetoothManager.connectionError = "Device not paired"
                } else if (errorMsg.includes("already connected")) {
                    bluetoothManager.connectionError = ""
                    bluetoothManager.refreshPairedDevices()
                } else {
                    bluetoothManager.connectionError = "Connection failed"
                }
            }

            deviceConnectProcess.outputData = ""
            deviceConnectProcess.errorData = ""
        }
    }

    property Process devicePairProcess: Process {
        running: false

        property string deviceAddress: ""
        property string deviceName: ""
        property string outputData: ""
        property string errorData: ""

        stdout: SplitParser {
            onRead: data => {
                devicePairProcess.outputData += data
            }
        }

        stderr: SplitParser {
            onRead: data => {
                devicePairProcess.errorData += data
            }
        }

        onExited: (code, status) => {
            bluetoothManager.isPairing = false

            if (code === 0) {
                bluetoothManager.pairingError = ""
                bluetoothManager.refreshPairedDevices()
            } else {
                let errorMsg = (devicePairProcess.errorData + devicePairProcess.outputData).toLowerCase()

                if (errorMsg.includes("already exists") || errorMsg.includes("already paired")) {
                    bluetoothManager.pairingError = ""
                    bluetoothManager.refreshPairedDevices()
                } else if (errorMsg.includes("not available") || errorMsg.includes("not found")) {
                    bluetoothManager.pairingError = "Device not available"
                } else if (errorMsg.includes("failed") || errorMsg.includes("error")) {
                    bluetoothManager.pairingError = "Pairing failed"
                } else {
                    bluetoothManager.pairingError = "Pairing failed"
                }
            }

            devicePairProcess.outputData = ""
            devicePairProcess.errorData = ""
        }
    }

    function refreshAvailableDevices() {
        if (availableDevices.length === 0) return

        for (let i = 0; i < availableDevices.length; i++) {
            let isPaired = pairedDevices.some(dev => dev.address === availableDevices[i].address)
            availableDevices[i].paired = isPaired

            if (isPaired) {
                let pairedDevice = pairedDevices.find(dev => dev.address === availableDevices[i].address)
                if (pairedDevice && pairedDevice.name) {
                    availableDevices[i].name = pairedDevice.name
                }
            }
        }
        // A same-reference reassignment emits nothing, so the list has to be a new array.
        availableDevices = availableDevices.slice()
    }

    property Process deviceNameProcess: Process {
        running: false

        property string deviceAddress: ""
        property string outputData: ""

        stdout: SplitParser {
            onRead: data => {
                deviceNameProcess.outputData += data
            }
        }

        stderr: SplitParser {
            onRead: data => {
            }
        }

        onExited: (code, status) => {
            let name = deviceNameProcess.outputData.trim()
            name = name.replace(/^(Alias|Name):\s*/i, "").trim()

            if (code === 0 && name.length > 0) {
                if (!name.match(/^[0-9A-Fa-f]{2}(?:[:-][0-9A-Fa-f]{2}){5}$/)) {
                    for (let i = 0; i < bluetoothManager.availableDevices.length; i++) {
                        if (bluetoothManager.availableDevices[i].address === deviceNameProcess.deviceAddress) {
                            bluetoothManager.availableDevices[i].name = name
                            bluetoothManager.availableDevices = bluetoothManager.availableDevices.slice()
                            break
                        }
                    }
                }
            }
            deviceNameProcess.outputData = ""

            if (bluetoothManager.deviceNameQueue.length > 0) {
                Qt.callLater(() => bluetoothManager.fetchNextQueuedDeviceName())
            } else if (deviceNameFetchTimer.currentIndex < deviceNameFetchTimer.addresses.length) {
                deviceNameFetchTimer.start()
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            refreshStatus()
        })
    }

    Component.onDestruction: {
        if (dbusMonitor.running) {
            dbusMonitor.running = false
        }
        if (bluetoothScanProcess.running) {
            bluetoothScanProcess.running = false
        }
    }
}
