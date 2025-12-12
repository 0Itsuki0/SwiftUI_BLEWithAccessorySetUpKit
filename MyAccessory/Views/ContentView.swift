//
//  ContentView.swift
//  MyAccessory
//
//  Created by Itsuki on 2025/12/10.
//

import SwiftUI

struct ContentView: View {
    @Environment(BluetoothPeripheralManager.self) private var peripheralManager
    
    var body: some View {
        
        @Bindable var peripheralManager = peripheralManager
        
        NavigationStack {
            VStack(spacing: 48) {
                CounterView(count: $peripheralManager.count)
                                
                VStack(spacing: 16) {
                    Toggle("Advertise", isOn: $peripheralManager.isAdvertising)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("Connected Centrals")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(self.peripheralManager.subscribedCentralCount)")
                            .foregroundStyle(.secondary)
                    }
                    
                    if let error = peripheralManager.error {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(" ")
                    }
                }
                .padding(.horizontal, 24)
                
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.yellow.opacity(0.1))
            .navigationTitle("BLE Accessory")
        }
    }
}



#Preview {
    ContentView()
        .environment(BluetoothPeripheralManager())
}
