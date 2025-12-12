//
//  Int.swift
//  AccessorySetupKit+WiFiInfrastructure
//
//  Created by Itsuki on 2025/12/12.
//


import Foundation

extension Int {
    var data: Data {
        let string = "\(self)"
        return Data(string.utf8)
    }
    
    static func fromData(_ data: Data) -> Int? {
        guard let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return Int(string)
    }
}
