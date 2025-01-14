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
        ZStack {
            VStack {
                Text(printer.stateMessage)
                ToolView()
            }
            VStack {
                if !printer.errors.isEmpty {
                    ForEach(printer.errors) { error in
                        Printer.ErrorPopup(
                            title: error.title,
                            message: error.message,
                            dismiss: {
                                printer.dismissErrorPopup(error)
                            })
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PreviewEnvironment.printer)
}
