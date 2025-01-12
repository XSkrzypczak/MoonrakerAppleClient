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
            
        }
    }
}

struct AxisPositionField: View {
    @EnvironmentObject var printer: Printer
    
    var body: some View {
        VStack {
            
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

struct HomeButton: View {
    @EnvironmentObject var printer: Printer
    
    let axis: Printer.Axis
    
    var body: some View {
        Button(action: {
            Task {
                await printer.homeAxis(axis)
            }
        }, label: {
            HStack {
                Image(systemName: "house.fill")
                Text("\(axis.description.uppercased())")
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
        })
    }
}

#Preview("ToolView") {
    ToolView()
        .environmentObject(Printer(url: URL(string:"ws://192.168.88.39:7125")!))
}
