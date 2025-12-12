//
//  AccessoryManager.swift
//  AccessorySetupKit+WiFiInfrastructure
//
//  Created by Itsuki on 2025/12/12.
//

import SwiftUI
import AccessorySetupKit
import CoreBluetooth

@Observable
class AccessoryManager {
    
    var counterPaired: Bool {
        return self.accessorySessionManager.counterPaired
    }
    
    var counterPeripheralConnected: Bool {
        return self.counterPeripheralState == .connected
    }
    
    var counterPeripheralState: CBPeripheralState {
        return self.bluetoothManager.counterPeripheralState
    }
    
    var counterCharacteristicFound: Bool {
        return self.bluetoothManager.counterCharacteristicFound
    }
    
    var count: Int {
        return self.bluetoothManager.count
    }
    
    var bluetoothState: CBManagerState {
        return self.bluetoothManager.bluetoothState
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
            
    private var accessorySessionManager = AccessorySessionManager()
            
    @ObservationIgnored
    private var accessoryErrorTask: Task<Void, Error>?

    
    private(set) var bluetoothManager = BluetoothCentralManager()
    
    @ObservationIgnored
    private var bluetoothErrorTask: Task<Void, Error>?

    init() {
        
        self.accessorySessionManager.handleAccessoryAdded = {
            guard let bluetoothIdentifier = self.accessorySessionManager.counterAccessory?.bluetoothIdentifier else {
                return
            }
            
            // Initialize CBCentralManager after accessory added.
            //
            // In the case of migrating an accessory,
            // if we  initialize a CBCentralManager before migration is complete,
            // we will receives an error event and the picker fails to appear.
            self.bluetoothManager.initCBCentralManager()
            self.bluetoothManager.counterAccessoryBluetoothId = bluetoothIdentifier
            
        }
        
        self.accessorySessionManager.handleAccessoryRemoved = {
            if self.counterPeripheralConnected == true {
                self.disconnectCounter()
            }
            self.bluetoothManager.deinitCBCentralManager()
        }
        
        self.accessoryErrorTask = Task {
            for await error in self.accessorySessionManager.errorsStream {
                self.error = error
            }
        }
        
        self.bluetoothErrorTask = Task {
            for await error in self.bluetoothManager.errorsStream {
                self.error = error
            }
        }
    }
    
    
    func presentAccessoryPicker() async {
        do {
            try await self.accessorySessionManager.presentAccessoryPicker()
        } catch(let error) {
            self.error = error
        }
    }

    
    func connectCounter() {
        do {
            try self.bluetoothManager.retrieveCounterPeripheral()
            try self.bluetoothManager.connectCounterPeripheral()
        } catch (let error) {
            self.error = error
        }
    }
    
    func discoverCounterCharacteristic() {
        do {
            try self.bluetoothManager.discoverCounterCharacteristic()
        } catch (let error) {
            self.error = error
        }
    }
    
    func setCount(_ count: Int) {
        do {
            try self.bluetoothManager.setCount(count)
        } catch(let error) {
            self.error = error
        }
    }

    func disconnectCounter() {
        self.bluetoothManager.disconnectCounterPeripheral()
    }
    
    
    func removeCounter() async  {
        if self.counterPeripheralConnected == true {
            self.disconnectCounter()
        }

        do {
            try await self.accessorySessionManager.removeCounter()
        } catch (let error) {
            self.error = error
        }
        
        self.bluetoothManager.deinitCBCentralManager()
    }

}
