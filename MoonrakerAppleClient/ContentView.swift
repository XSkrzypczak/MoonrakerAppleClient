//
//  ContentView.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 16/10/2024.
//

import SwiftUI
import AnyCodable

struct ContentView: View {
    @StateObject var printer = Printer(url: URL(string:"ws://192.168.88.39:7125/websocket")!) //change url to your printer websocket
    
    
    var body: some View {
        VStack {
            Button("refresh") {
                Task {
                    try await printer.fetchPrinterInfo()
                }
            }
            Text(printer.stateMessage)
            Text(printer.klippyStatus.description)
            
            Text(printer.printerStatus.description)
            
            Text("Extruder temperature: \(String(format: "%.1f", printer.extruder.temperature))")
            Text("Extruder target: \(String(format: "%.1f", printer.extruder.target))")
            Text("Heatbed temperature: \(String(format: "%.1f", printer.heaterBed.temperature))")
            Text("Heatbed target: \(String(format: "%.1f", printer.heaterBed.target))")
            Text("Filename: \(printer.printStats.filename)")
            Text("Postion: \(printer.toolhead.position)")
            
            List {
                ForEach(printer.gcodes) { gcode in
                    VStack(alignment: .leading) {
                        Text(gcode.message)
                        Text(String(DateFormatter.localizedString(from: Date(timeIntervalSince1970: gcode.time), dateStyle: .medium, timeStyle: .short)))
                        Text(gcode.type.rawValue)
                    }
                }
            }
        }
        .padding()
    }
}
#Preview {
    ContentView()
}
