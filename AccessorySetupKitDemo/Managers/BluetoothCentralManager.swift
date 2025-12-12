//
//  BluetoothCentralManager.swift
//  AccessorySetupKit+WiFiInfrastructure
//
//  Created by Itsuki on 2025/12/12.
//


import CoreBluetooth
import SwiftUI

// MARK: Errors
extension BluetoothCentralManager {
    enum BluetoothCentralError: Error {
        case managerNotInitialized
        case bluetoothNotAvailable
        
        case counterPeripheralNotDiscovered
        case counterCharacteristicNotDiscovered

        case failToConnect(Error)
        case failToDisconnect(Error)
        
        case failToDiscoverService(Error)
        case failToDiscoverCharacteristic(Error)
        case failToUpdateValue(Error)
        case failToUpdateNotify(Error)
    }

}

// When migrating with AccessorySetupKit
// Don’t initialize a CBCentralManager before migration is complete.
// Otherwise, the accessory picker fails to appear and we will receive an error
@Observable
class BluetoothCentralManager: NSObject {
    var counterAccessoryBluetoothId: UUID? = nil
    
    // since CBPeripheral cannot trigger any view updates,
    // we cannot use a calculated variable here, ie:
    // return self.counterPeripheral?.state
    private(set) var counterPeripheralState: CBPeripheralState = .disconnected
    
    // start with true to avoid showing error message in view
    // only set to false if we have indeed finish discovering the characteristic and the target one is not found.
    private(set) var counterCharacteristicFound: Bool = true
        
    private(set) var count: Int = 0

    // CBPeripheral will not trigger any view updates
    private var counterPeripheral: CBPeripheral? = nil {
        didSet {
            self.counterPeripheralState = self.counterPeripheral?.state ?? .disconnected
            if self.finishDiscoveringService && self.finishDiscoveringCharacteristic {
                self.counterCharacteristicFound = self.counterCharacteristic != nil
            }

            guard let data = self.counterCharacteristic?.value else {
                self.count = 0
                return
            }
            self.count = Int.fromData(data) ?? 0
        }
    }
    
    private var finishDiscoveringService: Bool {
        return self.counterPeripheral?.services != nil
    }
    
    private var finishDiscoveringCharacteristic: Bool {
        return self.counterService?.characteristics != nil
    }
    
    private var counterService: CBService? {
        return self.counterPeripheral?.services?.first(where: {$0.uuid == CounterAccessory.serviceUUID})
    }
    
    private var counterCharacteristic: CBCharacteristic? {
        return self.counterService?.characteristics?.first(where: {$0.uuid == CounterAccessory.counterCharacteristicUUID})
    }
    
    private(set) var bluetoothState: CBManagerState = .poweredOff {
        didSet {
            if self.bluetoothState == .poweredOff, oldValue == .poweredOn {
                self.counterPeripheral = nil
                self.counterAccessoryBluetoothId = nil
            }
        }
    }
    
    private var centralManager: CBCentralManager?

    // for errors in the delegation functions
    let errorsStream: AsyncStream<Error>
    private let errorsContinuation: AsyncStream<Error>.Continuation

    
    override init() {
        (self.errorsStream, self.errorsContinuation) = AsyncStream.makeStream(of: Error.self)
        super.init()
    }
    
    // In the case of migrating an accessory,
    // Don’t initialize a CBCentralManager before migration is complete.
    // If you do, your callback handler receives an error and the picker fails to appear.
    func initCBCentralManager() {
        guard self.centralManager == nil else { return }
        self.centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: true,
                // restoring state requires background mode
                // CBCentralManagerOptionRestoreIdentifierKey: NSString("AccessoryCentralManager")
            ]
        )
    }
    
    func deinitCBCentralManager() {
        self.centralManager = nil
        self.counterPeripheral = nil
        self.counterAccessoryBluetoothId = nil
    }
    
    func retrieveCounterPeripheral() throws {
        guard self.bluetoothState == .poweredOn else {
            throw BluetoothCentralError.bluetoothNotAvailable
        }
        guard let peripheralUUID = self.counterAccessoryBluetoothId else { return }
        guard self.counterPeripheral == nil || self.counterPeripheral?.identifier != peripheralUUID else { return }
        
        self.counterPeripheral = self.centralManager?.retrievePeripherals(withIdentifiers: [peripheralUUID]).first
    }
    
    func connectCounterPeripheral() throws {
        guard let counterPeripheral = self.counterPeripheral else {
            throw BluetoothCentralError.counterPeripheralNotDiscovered
        }
        try self.connectPeripheral(counterPeripheral)
        // set it manually here to avoid UI interactions
        self.counterPeripheralState = .connecting
    }

    func discoverCounterCharacteristic() throws {
        guard let counterService = self.counterService, let counterPeripheral = self.counterPeripheral else {
            throw BluetoothCentralError.counterPeripheralNotDiscovered
        }

        counterPeripheral.discoverCharacteristics([CounterAccessory.counterCharacteristicUUID], for: counterService)
    }

    func setCount(_ count: Int) throws {
        guard let counterPeripheral = self.counterPeripheral else {
            throw BluetoothCentralError.counterPeripheralNotDiscovered
        }
        
        guard let counterCharacteristic = self.counterCharacteristic else {
            throw BluetoothCentralError.counterCharacteristicNotDiscovered
        }
        
        try self.writeValue(counterPeripheral, data: count.data, for: counterCharacteristic, writeType: .withResponse)
    }
    
    
    func disconnectCounterPeripheral() {
        guard let counterPeripheral = self.counterPeripheral else { return }
        self.disconnectPeripheral(counterPeripheral)
    }

}

// MARK: Private helpers
extension BluetoothCentralManager {
    private func connectPeripheral(_ peripheral: CBPeripheral) throws {
        guard self.bluetoothState == .poweredOn else {
            throw BluetoothCentralError.bluetoothNotAvailable
        }
        
        guard let centralManager = self.centralManager else {
            throw BluetoothCentralError.managerNotInitialized
        }
        
        centralManager.connect(peripheral, options: [CBConnectPeripheralOptionEnableAutoReconnect: true])
    }
    
    private func writeValue(_ peripheral: CBPeripheral, data: Data, for characteristic: CBCharacteristic, writeType: CBCharacteristicWriteType) throws {
        guard self.bluetoothState == .poweredOn else {
            throw BluetoothCentralError.bluetoothNotAvailable
        }

        peripheral.writeValue(data, for: characteristic, type: writeType)
    }
    
    private func disconnectPeripheral(_ peripheral: CBPeripheral) {
        guard let centralManager = self.centralManager else { return }
        if peripheral.state == .connected {
            for service in (peripheral.services ?? [] as [CBService]) {
                for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
                    peripheral.setNotifyValue(false, for: characteristic)
                }
            }
        }
        if peripheral.state != .disconnected || peripheral.state != .disconnecting  {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        // not calling updatePeripheral here but wait for the cancelPeripheralConnection result in the delegation function.
    }
    
    private func updatePeripheral(_ peripheral: CBPeripheral) {
        if peripheral.identifier == self.counterAccessoryBluetoothId {
            self.counterPeripheral = peripheral
        }
    }
}


// MARK: CBCentralManagerDelegate
extension BluetoothCentralManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(#function)
        self.bluetoothState = central.state
    }
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print(#function)
        self.updatePeripheral(peripheral)
        
        guard peripheral.identifier == self.counterAccessoryBluetoothId else {
            return
        }
        
        peripheral.delegate = self
        peripheral.discoverServices([CounterAccessory.serviceUUID])
        
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: (any Error)?) {
        print(#function)
        self.updatePeripheral(peripheral)
        
        // Disconnect not due to the cancelPeripheralConnection operation
        if let error {
            self.errorsContinuation.yield(BluetoothCentralError.failToDisconnect(error))
            // not automatically reconnecting
            if !isReconnecting {
                try? self.connectPeripheral(peripheral)
            }
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        print(#function)
        if let error {
            self.errorsContinuation.yield(BluetoothCentralError.failToConnect(error))
        }
        
        // to perform any clean up
        self.disconnectPeripheral(peripheral)
        self.updatePeripheral(peripheral)
    }
    
}


// MARK: CBPeripheralDelegate
extension BluetoothCentralManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print(#function)
        self.updatePeripheral(peripheral)
    }
    
    // NOTE:
    // If we are not discovering any services without an error, ie: peripheral.services is an empty array
    // make sure that on the peripheral side, those services are indeed added to the CBPeripheralManager.
    // PS: the peripheral does NOT have to be advertising though.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        print(#function)
        self.updatePeripheral(peripheral)

        if let error {
            self.errorsContinuation.yield(BluetoothCentralError.failToDiscoverService(error))
            return
        }
        
        do {
            try self.discoverCounterCharacteristic()
        } catch(let error) {
            self.errorsContinuation.yield(error)
        }

    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        print(#function)
        self.updatePeripheral(peripheral)

        if let error {
            self.errorsContinuation.yield(BluetoothCentralError.failToDiscoverCharacteristic(error))
            return
        }
        
        guard let counterCharacteristic = self.counterCharacteristic else { return }
        peripheral.setNotifyValue(true, for: counterCharacteristic)
        peripheral.readValue(for: counterCharacteristic)

    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        print(#function)
        self.updatePeripheral(peripheral)

        if let error {
            self.errorsContinuation.yield(BluetoothCentralError.failToDiscoverCharacteristic(error))
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        print(#function)
        
        self.updatePeripheral(peripheral)

        if let error {
            self.errorsContinuation.yield(BluetoothCentralError.failToDiscoverCharacteristic(error))
        }

    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        self.updatePeripheral(peripheral)
        if let counterCharacteristic = self.counterCharacteristic, !counterCharacteristic.isNotifying {
            // read value
            peripheral.readValue(for: counterCharacteristic)
        }
    }
}

