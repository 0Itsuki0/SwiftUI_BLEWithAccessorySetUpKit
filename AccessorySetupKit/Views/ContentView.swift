//
//  ContentView.swift
//  AccessorySetupKit+WiFiInfrastructure
//
//  Created by Itsuki on 2025/12/12.
//



import SwiftUI
import AccessorySetupKit
import CoreBluetooth


struct ContentView: View {
    @Environment(AccessoryManager.self) private var accessoryManager
    @Environment(\.openURL) private var openURL
    
    @State private var count: Int = 0
    
    var body: some View {
        
        NavigationStack {
            VStack(spacing: 16) {
                if self.accessoryManager.counterPaired {
                    if self.accessoryManager.bluetoothState == .poweredOff {
                        ContentUnavailableView(label: {
                            Label("Bluetooth Off", systemImage: "antenna.radiowaves.left.and.right.slash")
                        }, description: {
                            Text("Please turn on your Bluetooth first.")
                        }, actions: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                Button(action: {
                                    self.openURL(url)
                                }, label: {
                                    Text("Add Accessory")
                                })
                            }
                        })
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(spacing: 48) {
                        CounterView(count: $count)
                            .disabled(!(self.accessoryManager.counterCharacteristicFound && self.accessoryManager.counterPeripheralConnected))
                        
                        VStack(spacing: 16) {
                            
                            self.connectionButton()
                            
                            Button(action: {
                                Task {
                                    await self.accessoryManager.removeCounter()
                                }
                            }, label: {
                                Text("Remove Accessory")
                                    .font(.headline)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity)
                                    .lineLimit(1)
                            })
                            .buttonStyle(.glassProminent)

                            
                            Group {
                                if self.accessoryManager.counterPeripheralConnected && !self.accessoryManager.counterCharacteristicFound {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Counter characteristic not found!")
                                            Spacer()
                                            
                                            Button(action: {
                                                self.accessoryManager.discoverCounterCharacteristic()
                                            }, label: {
                                                Text("Retry")
                                            })
                                        }
                                        
                                        Text("Is the service added to the accessory?")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(height: 48)
                        }
                        .padding(.horizontal, 16)

                    }


                } else {
                    ContentUnavailableView(label: {
                        Label("No Paired Counter", systemImage: "link.badge.plus")
                    }, description: {
                        Text("Please pair with the BLE Accessory first.")
                    }, actions: {
                        Button(action: {
                            Task {
                                await self.accessoryManager.presentAccessoryPicker()
                            }
                        }, label: {
                            Text("Add Accessory")
                        })
                    })
                    .fixedSize(horizontal: false, vertical: true)
                }
                
                if let error = self.accessoryManager.error {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: self.accessoryManager.counterCharacteristicFound ? .leading : .center)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                    
                } else {
                    Text(" ")
                }
                
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.yellow.opacity(0.1))
            .navigationTitle("App For Set Up BLE")
            .onChange(of: self.accessoryManager.count, initial: true, {
                self.count = self.accessoryManager.count
            })
            .onChange(of: self.count, {
                guard self.count != self.accessoryManager.count else {
                    return
                }
                self.accessoryManager.setCount(self.count)
            })
        }
    }
    
    @ViewBuilder
    private func connectionButton() -> some View {
        
        let buttonParameters: (String, ()->Void) = switch self.accessoryManager.counterPeripheralState {
        case .connected:
            ("Disconnect", {
                self.accessoryManager.disconnectCounter()
            })
        case .connecting:
            ("Connecting...", {})
        case .disconnected:
            ("Connect", {
                self.accessoryManager.connectCounter()
            })
        case .disconnecting:
            ("Disconnecting...", {})
        @unknown default:
            ("Apple is bugging...", {})
        }
        
        Button(action: buttonParameters.1, label: {
            Text(buttonParameters.0)
                .font(.headline)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
        })
        .buttonStyle(.glassProminent)
        .disabled(self.accessoryManager.counterPeripheralState == .connecting || self.accessoryManager.counterPeripheralState == .disconnecting)
    }
}
