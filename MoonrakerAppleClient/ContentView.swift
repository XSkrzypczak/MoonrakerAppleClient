//
//  ContentView.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 16/10/2024.
//

import SwiftUI

struct ContentView: View {
    var printer = PrinterClient(url: URL(string:"ws://192.168.88.39:7125/websocket")!) //change url to your printer websocket
    var body: some View {
        Button("Test") {
            Task {
                //Home X axis and get server info
                await printer.sendRequest(method: "printer.gcode.script", params: ["script": "G28 X"], id: 7466)
                await printer.sendRequest(method: "server.info", id: 7465)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
