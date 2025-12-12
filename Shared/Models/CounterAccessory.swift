//
//  CounterAccessory.swift
//  AccessorySetupKit+WiFiInfrastructure
//
//  Created by Itsuki on 2025/12/12.
//

import CoreBluetooth
import SwiftUI

// A Simple Counter
class CounterAccessory {
    
    static let counterCharacteristicUUID: CBUUID = CBUUID(string: "24F31983-2703-434D-AD32-CC85CC66EBEC")
    static let counterCharacteristic = CBMutableCharacteristic(
        type: counterCharacteristicUUID,
        properties: [.read, .write, .writeWithoutResponse, .notify],
        value: nil,
        permissions: [.readable, .writeable]
    )
    
    // for CBAdvertisementDataLocalNameKey
    static let name: String = "Itsuki's Counter"
    
    // for CBAdvertisementDataServiceUUIDsKey
    //
    // IMPORTANT:
    // Make sure that the NSAccessorySetupBluetoothServices (info.plist key) in the main app is set to the UPPERCASE of the string value.
    // ie: E0D678AE-DE7B-40CE-9CB4-A83AFF0D7C4B instead of e0d678ae-de7b-40ce-9cb4-a83aff0d7c4b
    // **regardless** whether if we have upper or lower case here.
    // Because when the system tries to match the CBUUID we specify in ASDiscoveryDescriptor.bluetoothServiceUUID with that in our info.plist,
    // the CBUUID of ASDiscoveryDescriptor.bluetoothServiceUUID will be converted to UPPERCASE automatically
    static let serviceUUID: CBUUID = CBUUID(string: "E0D678AE-DE7B-40CE-9CB4-A83AFF0D7C4B")
    
    static var service: CBMutableService {
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [counterCharacteristic]
        service.includedServices = []
        return service
    }
}
