import Foundation
import CoreBluetooth
import Combine

struct DiscoveredHRDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral

    static func == (lhs: DiscoveredHRDevice, rhs: DiscoveredHRDevice) -> Bool {
        lhs.id == rhs.id
    }
}

enum HRConnectionState: Equatable {
    case bluetoothOff
    case unauthorized
    case disconnected
    case scanning
    case connecting(String)
    case connected(String)

    var label: String {
        switch self {
        case .bluetoothOff: return "Bluetooth spento"
        case .unauthorized: return "Permesso Bluetooth negato"
        case .disconnected: return "Fascia non collegata"
        case .scanning: return "Ricerca fascia cardio..."
        case .connecting(let name): return "Connessione a \(name)..."
        case .connected(let name): return "Collegata: \(name)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

@MainActor
final class HeartRateManager: NSObject, ObservableObject {
    @Published private(set) var connectionState: HRConnectionState = .disconnected
    @Published private(set) var currentBPM: Int?
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var discoveredDevices: [DiscoveredHRDevice] = []
    @Published private(set) var lastUpdated: Date?

    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementUUID = CBUUID(string: "2A37")
    private let batteryServiceUUID = CBUUID(string: "180F")
    private let batteryLevelUUID = CBUUID(string: "2A19")

    private let lastDeviceKey = "cardiopacerun.lastPeripheralUUID"

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var shouldAutoReconnect = true

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        guard centralManager.state == .poweredOn else {
            updateStateFromCentral(centralManager.state)
            return
        }
        shouldAutoReconnect = true
        discoveredDevices.removeAll()
        connectionState = .scanning
        // Scansiona tutti i dispositivi che espongono il servizio Heart Rate standard (0x180D),
        // inclusa la fascia iGPSPORT HR50.
        centralManager.scanForPeripherals(
            withServices: [heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        centralManager.stopScan()
        if case .scanning = connectionState {
            connectionState = .disconnected
        }
    }

    func connect(to device: DiscoveredHRDevice) {
        shouldAutoReconnect = true
        centralManager.stopScan()
        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self
        connectionState = .connecting(device.name)
        UserDefaults.standard.set(device.id.uuidString, forKey: lastDeviceKey)
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        shouldAutoReconnect = false
        centralManager.stopScan()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        currentBPM = nil
        batteryLevel = nil
        connectionState = .disconnected
    }

    func forgetSavedDevice() {
        UserDefaults.standard.removeObject(forKey: lastDeviceKey)
        disconnect()
    }

    private func attemptReconnectSavedDevice() {
        guard shouldAutoReconnect,
              centralManager.state == .poweredOn,
              let uuidString = UserDefaults.standard.string(forKey: lastDeviceKey),
              let uuid = UUID(uuidString: uuidString) else {
            return
        }

        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let saved = peripherals.first {
            connectedPeripheral = saved
            saved.delegate = self
            let name = saved.name ?? "Fascia Cardio"
            connectionState = .connecting(name)
            centralManager.connect(saved, options: nil)
        }
    }

    private func updateStateFromCentral(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            if connectedPeripheral == nil {
                connectionState = .disconnected
                attemptReconnectSavedDevice()
            }
        case .poweredOff:
            currentBPM = nil
            batteryLevel = nil
            connectionState = .bluetoothOff
        case .unauthorized:
            connectionState = .unauthorized
        default:
            connectionState = .disconnected
        }
    }

    /// Decodifica il pacchetto standard Bluetooth SIG Heart Rate Measurement (0x2A37)
    private func parseHeartRate(from data: Data) -> Int? {
        guard data.count >= 2 else { return nil }
        let bytes = [UInt8](data)
        let flags = bytes[0]
        let isUInt16 = (flags & 0x01) != 0

        if isUInt16 {
            guard bytes.count >= 3 else { return nil }
            return Int(UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
        } else {
            return Int(bytes[1])
        }
    }
}

extension HeartRateManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            self.updateStateFromCentral(state)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheral.name ?? advertisedName ?? "Fascia Cardio BLE"
        let rssiValue = RSSI.intValue

        Task { @MainActor in
            let item = DiscoveredHRDevice(
                id: peripheral.identifier,
                name: name,
                rssi: rssiValue,
                peripheral: peripheral
            )
            if let idx = self.discoveredDevices.firstIndex(where: { $0.id == item.id }) {
                self.discoveredDevices[idx] = item
            } else {
                self.discoveredDevices.append(item)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let name = peripheral.name ?? "Fascia Cardio"
        Task { @MainActor in
            self.connectionState = .connected(name)
            peripheral.delegate = self
            peripheral.discoverServices([self.heartRateServiceUUID, self.batteryServiceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            self.currentBPM = nil
            self.connectionState = .disconnected
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            self.currentBPM = nil
            self.batteryLevel = nil
            if self.shouldAutoReconnect, self.centralManager.state == .poweredOn {
                let name = peripheral.name ?? "Fascia Cardio"
                self.connectionState = .connecting(name)
                self.centralManager.connect(peripheral, options: nil)
            } else {
                self.connectionState = .disconnected
            }
        }
    }
}

extension HeartRateManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { return }
        Task { @MainActor in
            for service in services {
                if service.uuid == self.heartRateServiceUUID {
                    peripheral.discoverCharacteristics([self.heartRateMeasurementUUID], for: service)
                } else if service.uuid == self.batteryServiceUUID {
                    peripheral.discoverCharacteristics([self.batteryLevelUUID], for: service)
                }
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil, let characteristics = service.characteristics else { return }
        Task { @MainActor in
            for characteristic in characteristics {
                if characteristic.uuid == self.heartRateMeasurementUUID {
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if characteristic.uuid == self.batteryLevelUUID {
                    peripheral.readValue(for: characteristic)
                    if characteristic.properties.contains(.notify) {
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                }
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, let data = characteristic.value else { return }
        let uuid = characteristic.uuid

        Task { @MainActor in
            if uuid == self.heartRateMeasurementUUID {
                if let bpm = self.parseHeartRate(from: data), bpm > 25, bpm < 240 {
                    self.currentBPM = bpm
                    self.lastUpdated = Date()
                }
            } else if uuid == self.batteryLevelUUID, let first = data.first {
                self.batteryLevel = Int(first)
            }
        }
    }
}
