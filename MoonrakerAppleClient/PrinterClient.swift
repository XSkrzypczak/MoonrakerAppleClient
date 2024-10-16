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
    
    //store responses we wait for
    private var expectedResponses: [Int: CheckedContinuation<Any, Error>] = [:]
    //store request we want to send
    private var pendingRequests: [Int: CheckedContinuation<Void, Error>] = [:]
    
    
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
            handleResponse(string)
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
        private let jsonrpc: String
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
    
    struct JsonRpcResponse: Codable {
        let jsonrpc: String
        let result: AnyCodable
        let id: Int
    }
    
    struct JsonRpcError: Codable, Error {
        let jsonrpc: String
        let error: ErrorDetails
        let id: Int
        
        struct ErrorDetails: Codable, Error {
            let code: Int
            let message: String
        }
    }
    
    //use only for sending requests where respons is "ok" or is not used
    func sendRequest(method: String, params: [String: AnyCodable]? = nil, id: Int) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = continuation
            let request = JsonRpcRequest(method: method, params: params, id: id)
            do {
                let requestData = try JSONEncoder().encode(request)
                socket.write(data: requestData)
            } catch {
                // If encoding fails, remove the pending request and resume with an error
                pendingRequests.removeValue(forKey: id)
                continuation.resume(throwing: error)
            }
        }
    }
    
    func getRequest(method: String, params: [String: AnyCodable]? = nil, id: Int) async throws -> Any {
        return try await withCheckedThrowingContinuation { continuation in
            expectedResponses[id] = continuation
            Task {
                do {
                    try await sendRequest(method: method, params: params, id: id)
                } catch {
                    expectedResponses.removeValue(forKey: id)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func handleResponse(_ response: String) {
        guard let data = response.data(using: .utf8) else {
            print("Invalid UTF-8 data received")
            return
        }
        //try to decode response and match it to request/response we wait for. if it fails throw an error to SendRequest
        do {
            // Try to decode the response as a JSON-RPC response, if it fails decode as a JSON-RPC error
            if let json = try? JSONDecoder().decode(JsonRpcResponse.self, from: data) {
                if let continuation = expectedResponses[json.id] {
                    continuation.resume(returning: json.result.value)
                    expectedResponses.removeValue(forKey: json.id)
                } else if let continuation = pendingRequests[json.id] {
                    pendingRequests.removeValue(forKey: json.id)
                    continuation.resume()
                }
            } else if let json = try? JSONDecoder().decode(JsonRpcError.self, from: data) {
                //we can pass error only to sendRequest because it will pass it to getRequest if used
                if let continuation = pendingRequests[json.id] {
                    continuation.resume(throwing: json.error)
                    pendingRequests.removeValue(forKey: json.id)
                }
            }
        }
    }
}
