//
//  Printer.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 16/10/2024.
//

import Foundation
import Starscream
//TODO: fork AnyCodable and add privacy manifest
import AnyCodable

//TODO: Add thrown error handling
class Printer: WebSocketDelegate, ObservableObject {
    private let socket: WebSocket
    private let url: URL
    var isConnected: Bool = false
    var canSendRequest: Bool = false
    //store responses we wait for
    private var expectedResponses: [Int: CheckedContinuation<AnyCodable, Error>] = [:]
    //store request we want to send
    private var pendingRequests: [Int: CheckedContinuation<Void, Error>] = [:]
    
    //store printer info
    @Published var klippyStatus: KlippyStatus = .null
    @Published var printerStatus: PrinterStatus = .null
    @Published var stateMessage: String = "null"
    
    var printerObjects: [String] = []
    
    @Published var gcodes : [GCode] = []
    @Published var extruders: [Extruder] = []
    @Published var heaterBed: HeaterBed = HeaterBed()
    @Published var toolhead: Toolhead = Toolhead()
    @Published var printStats: PrintStats = PrintStats()
    @Published var gcodeMove: GcodeMove = GcodeMove()
    @Published var filamentFan: FilamentFan = FilamentFan()
    @Published var temperatureSensors: [TemperatureSensor] = []
    @Published var temperatureFans: [TemperatureFan] = []
    @Published var heaterFans: [HeaterFan] = []
    @Published var gcodeMacros: [String] = []
    
    init(url: URL) {
        self.url = url
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
    }
    
    struct Param {
        let key: String
        var value: Any
        
        init(key: String, values: Any) {
            self.key = key
            self.value = values
        }
    }
    
    struct JsonRpcRequest: Codable {
        private let jsonrpc: String
        let method: String
        var params: [String: AnyCodable]?
        let id: Int
        
        init(method: String, params: [Param]?, id: Int) {
            self.jsonrpc = "2.0"
            self.method = method
            self.id = id
            
            if let parameters = params {
                self.params = [:]
                for param in parameters {
                    self.params?[param.key] = AnyCodable(param.value)
                }
            } else {
                self.params = nil
            }
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
    
    struct JsonRpcNotification: Codable {
        let jsonrpc: String
        let method: String
        let params: AnyCodable?
        
        init(jsonrpc: String, method: String, params: AnyCodable?) {
            self.jsonrpc = jsonrpc
            self.method = method
            self.params = params
        }
    }
    
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            isConnected = true
            canSendRequest = true
            print("websocket is connected: \(headers)")
            Task {
                await initializeSubscriptions()
            }
        case .disconnected(let reason, let code):
            isConnected = false
            canSendRequest = false
            for continuation in expectedResponses {
                continuation.value.resume(throwing: WebSocketEvent.disconnected(reason, code) as! Error)
                expectedResponses.removeAll()
            }
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
    func initializeSubscriptions() async {
        do {
            try await fetchPrinterInfo()
            await statusUpdateSubscribe()
        } catch {
            print(error)
        }
    }
    
    func getRequestID() -> Int {
        let id = Int.random(in: 1...10000)
        if(expectedResponses.keys.contains(id) || pendingRequests.keys.contains(id)) {
            return getRequestID()
        }
        return id
    }
    //use only for sending requests where response is "ok" or is not used
    func sendRequest(method: String, params: [Param]? = nil, id: Int = 0) async throws {
        if canSendRequest {
            return try await withCheckedThrowingContinuation { continuation in
                let requestId = id == 0 ? getRequestID() : id
                pendingRequests[requestId] = continuation
                let request = JsonRpcRequest(method: method, params: params, id: requestId)
                do {
                    let requestData = try JSONEncoder().encode(request)
                    socket.write(data: requestData)
                    print("sent \(request)")
                    canSendRequest = false
                } catch {
                    // If encoding fails, remove the pending request and resume with an error
                    pendingRequests.removeValue(forKey: requestId)
                    continuation.resume(throwing: error)
                }
            }
        }
        else {
            throw NSError(domain: "PrinterClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot send request"])
        }
    }
    
    func getRequest(method: String, params: [Param]? = nil) async throws -> AnyCodable {
        return try await withCheckedThrowingContinuation { continuation in
            let id = getRequestID()
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
                    print("received \(json)")
                    continuation.resume(returning: json.result)
                    if let continuation = pendingRequests[json.id] {
                        pendingRequests.removeValue(forKey: json.id)
                        continuation.resume()
                    }
                    expectedResponses.removeValue(forKey: json.id)
                } else if let continuation = pendingRequests[json.id] {
                    pendingRequests.removeValue(forKey: json.id)
                    continuation.resume()
                }
                canSendRequest = true
            } else if let json = try? JSONDecoder().decode(JsonRpcError.self, from: data) {
                //we can pass error only to sendRequest because it will pass it to getRequest if used
                if let continuation = pendingRequests[json.id] {
                    continuation.resume(throwing: json.error)
                    pendingRequests.removeValue(forKey: json.id)
                }
                canSendRequest = true
            }
            //notification handling
            else if let json = try? JSONDecoder().decode(JsonRpcNotification.self, from: data) {
                if let method = json.method as String? {
                    switch method {
                    case "notify_klippy_ready":
                        klippyStatus = .ready
                        Task {
                            try await fetchPrinterInfo()
                        }
                    case "notify_klippy_shutdown":
                        klippyStatus = .shutdown
                        Task {
                            try await fetchPrinterInfo()
                        }
                    case "notify_klippy_disconnected":
                        klippyStatus = .disconnected
                        Task {
                            try await fetchPrinterInfo()
                        }
                    case "notify_status_update":
                        handleStatusUpdate(json.params?.value ?? nil)
                    case "notify_gcode_response":
                        //TODO: Add handling of all types of responses
                        print("Got gcode response: \((json.params?.value as! [String])[0])")
                    default :
                        break
                    }
                }
            }
        }
    }
}
