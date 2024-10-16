//
//  PrinterClient.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 16/10/2024.
//

import Foundation
import Starscream
import AnyCodable

class PrinterClient: WebSocketDelegate {
    private let socket: WebSocket
    private let url: URL
    var isConnected: Bool = false
    
    init(url: URL) {
        self.url = url
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
    }
    
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            isConnected = true
            print("websocket is connected: \(headers)")
        case .disconnected(let reason, let code):
            isConnected = false
            print("websocket is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            print("Received text: \(string)")
            break
        case .binary(let data):
            print("Received data: \(data.count)")
        case .ping(_):
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            isConnected = false
        case .error(let error):
            isConnected = false
            handleError(error)
        case .peerClosed:
            break
        }
        
        func handleError(_ error: Error?) {
            if let e = error as? WSError {
                print("websocket encountered an error: \(e.message)")
            } else if let e = error {
                print("websocket encountered an error: \(e.localizedDescription)")
            } else {
                print("websocket encountered an error")
            }
        }
    }
    struct JsonRpcRequest: Codable {
        let jsonrpc: String
        let method: String
        let params: [String: AnyCodable]?
        let id: Int
        
        init(method: String, params: [String: AnyCodable]?, id: Int) {
            self.jsonrpc = "2.0"
            self.method = method
            self.params = params
            self.id = id
        }
    }
    
    func sendRequest(method: String, params: [String: AnyCodable]?, id: Int) async {
        let request =  JsonRpcRequest(method: method, params: params, id: id)
        socket.write(data: Data(try! JSONEncoder().encode(request)))
    }
}
