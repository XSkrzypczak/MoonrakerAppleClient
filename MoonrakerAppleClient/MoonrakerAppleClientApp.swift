//
//  MoonrakerAppleClientApp.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 16/10/2024.
//

import SwiftUI

struct PreviewEnvironment {
    static let printer: Printer = Printer(url: URL(string:"ws://192.168.88.39:7125/websocket")!)
}

@main
struct MoonrakerAppleClientApp: App {
    //TODO: add array of printers, change "printer" to "selectedPrinter"
    @StateObject private var printer = Printer(url: URL(string:"ws://192.168.88.39:7125/websocket")!) //change url to your printer websocket
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(printer)
        }
    }
}
