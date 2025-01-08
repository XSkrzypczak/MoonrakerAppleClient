//
//  ContentView.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 16/10/2024.
//

import SwiftUI
import AnyCodable

struct ContentView: View {
    @EnvironmentObject var printer: Printer
    
    var body: some View {
        VStack {
            Text(printer.stateMessage)
            ToolView()
            
        }
    }
}
#Preview {
    ContentView()
}
