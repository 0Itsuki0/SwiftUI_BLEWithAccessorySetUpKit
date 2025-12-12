//
//  BluetoothPeripheralManager.swift
//  AccessorySetupKit+WiFiInfrastructure
//
//  Created by Itsuki on 2025/12/10.
//

import SwiftUI
import CoreBluetooth


extension BluetoothPeripheralManager {
    enum BluetoothPeripheralError: Error {
        case managerNotInitialized
        case bluetoothNotAvailable
        
        // Transmit queue is full
        case failToUpdateCharacteristic
        
        case failToStartAdvertising(Error)
    }
}

@Observable
class BluetoothPeripheralManager: NSObject {
    
    var count: Int = 0 {
        didSet {
            // we still want to be able to update the value even when the bluetooth is not one, and
            // written failure will be re-tried in peripheralManagerIsReadyToUpdateSubscribers so we will not do anything here
            try? self.updateCharacteristicValue(value: count.data)
        }
    }
    
    // since CBCentral will not trigger any view updates,
    // we cannot use a calculated variable here.
    private(set) var subscribedCentralCount: Int = 0
    
    // CBCentral will not trigger any view updates
    private var subscribedCentrals: [CBCentral] = [] {
        didSet {
            self.subscribedCentralCount = self.subscribedCentrals.count
        }
    }

    var isAdvertising: Bool = false {
        didSet {
            do {
                isAdvertising ? try startAdvertising() : stopAdvertising()
            } catch (let error) {
                self.error = error
                self.isAdvertising = oldValue
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
    
    private(set) var error: Error? {
        didSet {
            if let error {
                print(error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                    self.error = nil
                })
            }
        }
    }
    
    
    private(set) var bluetoothState: CBManagerState = .poweredOff
    private var peripheralManager: CBPeripheralManager?
    
    private var serviceAdded: Bool = false
    
    private var advertisementData: [String: Any] {
        var advertisementData: [String: Any] = [:]
        advertisementData[CBAdvertisementDataLocalNameKey] = CounterAccessory.name
        advertisementData[CBAdvertisementDataServiceUUIDsKey] = [CounterAccessory.serviceUUID]
        return advertisementData
    }
    
    override init() {
        super.init()
        self.peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: [
                CBPeripheralManagerOptionShowPowerAlertKey: true,
                // to enable state restore with delegate function peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any])
                // this will requires background mode
                // CBPeripheralManagerOptionRestoreIdentifierKey: NSString(string: CounterAccessory.name)
            ]
        )
    }
    
    private func startAdvertising() throws {
        print(#function)
        
        guard let peripheralManager = self.peripheralManager else {
            throw BluetoothPeripheralError.managerNotInitialized
        }
        
        guard self.bluetoothState == .poweredOn else  {
            throw BluetoothPeripheralError.bluetoothNotAvailable
        }
        
        self.addService()
        
        peripheralManager.startAdvertising(advertisementData)

        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    
    private func stopAdvertising() {
        print(#function)
        
        guard self.bluetoothState == .poweredOn  else {
            return
        }

        peripheralManager?.stopAdvertising()
        // if we want other device to not be able to discover our services without us advertising,
        // uncomment the following line.
        // peripheralManager?.removeAllServices()
        
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private func addService() {
        guard self.bluetoothState == .poweredOn else { return }
        if !self.serviceAdded {
            peripheralManager?.add(CounterAccessory.service)
            self.serviceAdded = true
        }
    }
    
    
    private func updateCharacteristicValue(value: Data) throws {
        print(#function)
        guard self.bluetoothState == .poweredOn  else {
            throw BluetoothPeripheralError.bluetoothNotAvailable
        }

        guard let peripheralManager = self.peripheralManager else {
            throw BluetoothPeripheralError.managerNotInitialized
        }
        
        guard peripheralManager.updateValue(value, for: CounterAccessory.counterCharacteristic, onSubscribedCentrals: nil) else {
            // underlying transmit queue is full
            // will retry automatically in peripheralManagerIsReadyToUpdateSubscribers
            throw BluetoothPeripheralError.failToUpdateCharacteristic
        }
    }
}


// MARK: CBPeripheralManagerDelegate
// Additional delegation methods:
// - to monitor subscribed central: peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic)
// - to restore the previous state (such as subscribed added services and subscribed centrals): peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any])
extension BluetoothPeripheralManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print(#function)
        self.bluetoothState = peripheral.state
        self.addService()
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        print(#function)
        if let error {
            self.error = BluetoothPeripheralError.failToStartAdvertising(error)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        print(#function)
        if let error {
            self.isAdvertising = false
            self.error = BluetoothPeripheralError.failToStartAdvertising(error)
        }
    }

    // invoked after a failed call to updateValue:forCharacteristic:onSubscribedCentrals
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print(#function)
        do {
            try self.updateCharacteristicValue(value: self.count.data)
        } catch(let error) {
            self.error = error
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        let perviousServices = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] ?? []
        
        let characteristics = perviousServices.map(\.characteristics).filter({$0 != nil}).flatMap({$0!})
        let mutable = characteristics.map({$0 as? CBMutableCharacteristic}).filter({$0 != nil}).map({$0!})
        self.subscribedCentrals = mutable.map(\.subscribedCentrals).filter({$0 != nil}).flatMap({$0!})
    }
    
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if characteristic.uuid == CounterAccessory.counterCharacteristicUUID, !self.subscribedCentrals.contains(where: {$0.identifier == central.identifier}) {
            self.subscribedCentrals.append(central)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if characteristic.uuid == CounterAccessory.counterCharacteristicUUID {
            self.subscribedCentrals.removeAll(where: {$0.identifier == central.identifier})
        }
    }
    
    
    // invoked when Central made a read request
    // to have central receive the value of the characteristic, it need to be set using request.value
    // otherwise, central will not receive any update on the value of the characteristic in peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?)
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        switch request.characteristic.uuid {
        case CounterAccessory.counterCharacteristicUUID:
            request.value = self.count.data
        default:
            break
        }
        
        peripheral.respond(to: request, withResult: .success)
    }

    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print(#function)
        guard !requests.isEmpty else { return }

        var data = Data()

        for request in requests {
            guard var requestValue = request.value else { continue }
            requestValue = requestValue.dropFirst(request.offset)
            data.append(requestValue)
        }
        
        switch requests.first?.characteristic.uuid {
            
        case CounterAccessory.counterCharacteristicUUID:
            if let value = Int.fromData(data) {
                // setting the `count` will call `updateCharacteristicValue` automatically
                // so that other subscribed centrals (other than the one sends the request) will also receive the update
                self.count = value
            }
        default:
            break
        }

        if let first = requests.first {
            peripheral.respond(to: first, withResult: .success)
        }
    }

}
