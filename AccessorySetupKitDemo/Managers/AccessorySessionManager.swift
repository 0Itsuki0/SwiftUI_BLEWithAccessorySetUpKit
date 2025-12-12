//
//  AccessorySessionManager.swift
//  AccessorySetupKit+WiFiInfrastructure
//
//  Created by Itsuki on 2025/12/11.
//

import SwiftUI
import AccessorySetupKit

@Observable
class AccessorySessionManager {
    var handleAccessoryAdded: (() -> Void)?
    var handleAccessoryRemoved: (() -> Void)?

    var counterPaired: Bool {
        return self.counterAccessory != nil
    }
    
    // not using this property in this demo,
    // but if navigating to a different view is needed after pairing,
    // make sure to do it after picker dismissed.
    private(set) var isPickerDisplayed: Bool = false
    
    private(set) var counterAccessory: ASAccessory? = nil {
        didSet {
            if self.counterAccessory != nil {
                self.handleAccessoryAdded?()
            } else {
                self.handleAccessoryRemoved?()
            }
        }
    }

    private var accessorySession = ASAccessorySession()
            
    let errorsStream: AsyncStream<Error>
    private let errorsContinuation: AsyncStream<Error>.Continuation

    private var counterAccessoryDisplayItem: ASPickerDisplayItem {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = CounterAccessory.serviceUUID
        descriptor.supportedOptions.insert(.bluetoothPairingLE)
        
        // the name and productImage are just what is displayed in the picker and can be anything
        let item = ASPickerDisplayItem(
            name: CounterAccessory.name,
            productImage: UIImage(systemName: "5.arrow.trianglehead.counterclockwise")!,
            descriptor: descriptor
        )
        
        // setupOptions:
        // to specify behaviors like allowing renaming of the accessory during setup, or confirming accessory authorization before showing the setup view.
        item.setupOptions = [.rename]

        return item
    }


    init() {
        (self.errorsStream, self.errorsContinuation) = AsyncStream.makeStream(of: Error.self)

        let settings = ASPickerDisplaySettings.default
        // setting settings.discoveryTimeout to .unbounded will not work.
        // picker will not show up and we will get the following error print out to our terminal
        // SWIFT TASK CONTINUATION MISUSE: _createCheckedThrowingContinuation(_:) leaked its continuation without resuming it. This may cause tasks waiting on it to remain suspended forever.
        // settings.discoveryTimeout = .unbounded
        accessorySession.pickerDisplaySettings = settings

        self.accessorySession.activate(on: DispatchQueue.main, eventHandler: handleSessionEvent(_:))
        
    }
    
    
    func presentAccessoryPicker() async throws {
        // - To perform a one-time migration of previously-configured accessories:  https://developer.apple.com/documentation/accessorysetupkit/discovering-and-configuring-accessories#Use-the-picker-when-migrating-to-AccessorySetupKit
        // - To perform custom filtering and update picker after presenting: https://developer.apple.com/documentation/accessorysetupkit/discovering-and-configuring-accessories#Perform-custom-filtering
        try await self.accessorySession.showPicker(for: [self.counterAccessoryDisplayItem])
    }
    
    func removeCounter() async throws {
        guard let counterAccessory = self.counterAccessory else {
            return
        }
        try await self.removeAccessory(counterAccessory)
        self.counterAccessory = nil
    }
    
    private func removeAccessory(_ accessory: ASAccessory) async throws {
        try await self.accessorySession.removeAccessory(accessory)
    }
    
    
    private func handleSessionEvent(_ event: ASAccessoryEvent) {
        if let error = event.error {
            self.errorsContinuation.yield(error)
        }

        switch event.eventType {
        
        case .accessoryAdded:
            // Handle addition of an accessory by person using the app.
            guard let accessory = event.accessory else { return }
            self.processCounterEvent(accessory, isAdd: true)
        
        case .accessoryChanged:
            // Handle change of previously-added
            // accessory, if necessary.
            guard let accessory = event.accessory else { return }
            self.processCounterEvent(accessory, isAdd: true)

        case .activated:
            // Use previously-discovered accessories in
            // session.accessories, if necessary.
            guard let counter = self.accessorySession.accessories.first(where: {self.isAccessoryCounter($0)}) else { return }
            self.processCounterEvent(counter, isAdd: true)
            
        case .accessoryRemoved:
            guard let accessory = event.accessory else { return }
            self.processCounterEvent(accessory, isAdd: false)

        case .pickerDidPresent:
            self.isPickerDisplayed = true
            
        case .pickerDidDismiss:
            self.isPickerDisplayed = false

        default:
            print("Received event type \(String(describing: event.eventType))")
        }
    }
    
    private func processCounterEvent(_ accessory: ASAccessory, isAdd: Bool) {
        guard self.isAccessoryCounter(accessory) else { return }
        self.counterAccessory = isAdd ? accessory : nil
    }
    
    
    private func isAccessoryCounter(_ accessory: ASAccessory) -> Bool {
        return accessory.descriptor.bluetoothServiceUUID == CounterAccessory.serviceUUID
    }
}
