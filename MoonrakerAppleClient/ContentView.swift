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
    
    //objcets query request for testing
    @State var params = Printer.Param(
        key: "objects",
        values: [
            "extruder": nil,
            "fan": nil,
            "print_stats": nil
        ]
    )
    @State var method: String = "printer.objects.subscribe"
    
    var body: some View {
        VStack {
            Button("Send request") {
                
                Task {
                    do {
                        print(try await printer.getRequest(method: method, params: [params]))
                    } catch {
                        print("error: \(error)")
                    }
                }
            }
            Button("refresh") {
                Task {
                    try await printer.fetchPrinterInfo()
                }
            }
            Text(printer.stateMessage)
            Text(printer.klippyStatus.description)
        }
        .padding()
    }
}
#Preview {
    ContentView()
}
