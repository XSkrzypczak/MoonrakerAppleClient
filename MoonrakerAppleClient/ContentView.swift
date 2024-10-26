//
//  ContentView.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 16/10/2024.
//

import SwiftUI
import AnyCodable

struct ContentView: View {
    @StateObject var printer = PrinterClient(url: URL(string:"ws://192.168.88.39:7125/websocket")!) //change url to your printer websocket
    @State var paramKey: String = ""
    @State var paramValue: String = ""
    @State var rootParam: String = ""
    @State var params: [String: AnyCodable]?
    @State var method: String = ""
    
    var body: some View {
        VStack {
            TextField(
                "method",
                text: $method
            )
            .autocapitalization(.none)
            .autocorrectionDisabled()
            VStack {
                Text("New param")
                TextField(
                    "RootParam",
                    text: $rootParam
                )
                .autocapitalization(.none)
                .autocorrectionDisabled()
                TextField(
                    "Key",
                    text: $paramKey
                )
                .autocapitalization(.none)
                .autocorrectionDisabled()
                TextField(
                    "Value",
                    text: $paramValue
                )
                .autocorrectionDisabled()
                .autocapitalization(.none)
                Button("Add Parms") {
                    if(paramKey != "" && paramValue != "") {
                        if params == nil {
                            params = [:]
                        }
                        params?[paramKey] = AnyCodable(paramValue)
                        paramKey = ""
                        paramValue = ""
                    }
                }
                Button("Add Nested Parms") {
                    if !paramKey.isEmpty && !paramValue.isEmpty && !rootParam.isEmpty {
                        // Initialize params if nil
                        if params == nil {
                            params = [:]
                        }
                        
                        if var rootParams = params?[rootParam]?.value as? [String: AnyCodable] {
                            // Add to existing nested params
                            rootParams[paramKey] = AnyCodable(paramValue)
                            params?[rootParam] = AnyCodable(rootParams) // Update the dictionary
                        } else {
                            // Create new nested params if rootParam doesn't exist
                            let newRootParams: [String: AnyCodable] = [paramKey: AnyCodable(paramValue)]
                            params?[rootParam] = AnyCodable(newRootParams)
                        }
                        paramKey = ""
                        paramValue = ""
                        rootParam = ""
                    }
                }
                
                Button("Clear Parms") {
                    params = nil
                }
                List {
                    if params != nil {
                        ForEach((params?.keys.sorted())!, id: \.self) { key in
                            Text("\(key): \(params?[key]?.value ?? "nil")")
                        }
                    }
                }
                Button("Send request") {
                    
                    Task {
                        do {
                            print(try await printer.getRequest(method: method, params: params, id: 7466))
                        } catch {
                            print("error: \(error)")
                        }
                    }
                }
                
                Text(printer.klippyStatus.description)
            }
            .padding()
        }
    }
}
#Preview {
    ContentView()
}
