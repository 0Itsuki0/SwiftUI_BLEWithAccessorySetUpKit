//
//  CounterView.swift
//  AccessorySetupKit+WiFiInfrastructure
//
//  Created by Itsuki on 2025/12/11.
//

import SwiftUI

struct CounterView: View {
    @Binding var count: Int
    
    private let maximum: Int = 100
    private let minimum: Int = 0
    
    var body: some View {
        VStack {
            Text(CounterAccessory.name)
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)

            
            HStack(spacing: 24) {
                button(action: {
                    count = max(self.minimum, count - 1)
                }, labelImage: "minus.square.fill")

                Text("\(count)")
                    .font(.system(size: 120))
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .containerRelativeFrame(.horizontal, { length, axis in
                        return axis == .horizontal ? length * 0.5 : length
                    })
                
                button(action: {
                    count = min(self.maximum, count + 1)
                }, labelImage: "plus.square.fill")
            }
            .frame(maxWidth: .infinity)
            
            let text: String = switch count {
            case maximum:
                "Max Reached!"
            case minimum:
                "Min Reached!"
            default: " " // to keep line height
            }
            
            Text(text)
                .foregroundStyle(.secondary)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

        }
        
    }
    
    @ViewBuilder
    private func button(action: @escaping () -> Void, labelImage: String) -> some View {
        Button(action: action, label: {
            Image(systemName: labelImage)
                .font(.system(size: 40))
        })
        .buttonStyle(.borderless)
    }
}

#Preview {
    CounterView(count: .constant(0))
}
