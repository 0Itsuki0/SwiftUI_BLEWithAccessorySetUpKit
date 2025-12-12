//
//  MyAccessoryApp.swift
//  MyAccessory
//
//  Created by Itsuki on 2025/12/10.
//

import SwiftUI

@main
struct MyAccessoryApp: App {
    private let peripheralManager = BluetoothPeripheralManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(peripheralManager)
        }
    }
}
