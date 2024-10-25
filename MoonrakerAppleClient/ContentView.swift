//
//  ContentView.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 16/10/2024.
//

import SwiftUI
import AnyCodable

struct ContentView: View {
    var printer = PrinterClient(url: URL(string:"ws://192.168.88.39:7125/websocket")!) //change url to your printer websocket
    @State var paramKey: String = ""
    @State var paramValue: String = ""
    @State var params: [String: AnyCodable]?
    @State var method: String = ""
    
    var body: some View {
        VStack {
            TextField(
                "method",
                text: $method
            )
            VStack {
                Text("New param")
                TextField(
                    "Key",
                    text: $paramKey
                )
                TextField(
                    "Value",
                    text: $paramValue
                )
                Button("Add Parms") {
                    if(paramKey != "" && paramValue != "") {
                        params?[paramKey] = AnyCodable(paramValue)
                        paramKey = ""
                        paramValue = ""
                    }
                }
            }
            //TODO: add list of params
            Button("Send request") {
                
                Task {
                    do {
                        print(try await printer.getRequest(method: method, params: params, id: 7466))
                    } catch {
                        print("error: \(error)")
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
