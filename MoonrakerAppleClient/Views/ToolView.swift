//
//  ToolView.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 05/01/2025.
//

import SwiftUI

struct ToolView: View {
    @EnvironmentObject var printer: Printer
    var body: some View {
        VStack {
            MoveButton(axis: .x, isPositive: true)
        }
    }
}

struct MoveButton: View {
    @EnvironmentObject var printer: Printer
    let axis: Printer.Axis
    let isPositive: Bool
    var isEnabled: Bool {
        return printer.toolhead.homedAxes[axis] ?? false
    }
    
    var body: some View {
        Button(action: {
            Task {
                await printer.moveAxisRelative(axis: axis, distance: isPositive ? 1 : -1, speed: 100)
            }
        }, label: {
            switch axis {
            case .x:
                isPositive ? Image(systemName: "arrowshape.right.fill") : Image(systemName: "arrowshape.left.fill")
            case .y:
                isPositive ? Image(systemName: "arrowshape.up.fill") : Image(systemName: "arrowshape.down.fill")
            case .z:
                isPositive ? Image(systemName: "arrowshape.up.fill") : Image(systemName: "arrowshape.down.fill")
            default:
                Text("?")
            }
        })
        .disabled(!isEnabled)
    }
}

#Preview {
    ToolView()
        .environmentObject(Printer(url: URL(string:"ws://192.168.88.39:7125")!))
}
