//
//  AccessorySetupKit_WiFiInfrastructureApp.swift
//  AccessorySetupKit+WiFiInfrastructure
//
//  Created by Itsuki on 2025/12/10.
//

import SwiftUI

@main
struct AccessorySetupKitDemoApp: App {
    private let accessoryManager = AccessoryManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(self.accessoryManager)
        }
    }
}
