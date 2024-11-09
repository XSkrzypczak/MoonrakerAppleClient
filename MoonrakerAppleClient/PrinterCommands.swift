//
//  PrinterCommands.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 26/10/2024.
//

import Foundation
import AnyCodable

extension Printer {
    @MainActor
    func fetchPrinterInfo() async throws {
        do {
            //get response as dictionary
            guard let response = try await getRequest(method: "printer.info").value as? [String: Any] else {
                throw NSError(domain: "PrinterClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get printer info"])
            }
            //decode response to PrinterInfo
            let state: KlippyStatus = {
                switch response["state"] as? String {
                case "ready":
                    return .ready
                case "shutdown":
                    return .shutdown
                case "disconnected":
                    return .disconnected
                default:
                    return .null
                }
            }()
            
            self.klippyStatus = state
            self.stateMessage = response["state_message"] as? String ?? ""
        } catch {
            throw error
        }
    }
    
    func handleStatusUpdate(_ notification: Any?) {
        //get array of objects from status update
        guard let response = notification as? [Any],
              let objects = response.first as? [String: Any] else {
            return
        }
        for object in objects {
            if object.key == "extruder" {
                guard let extruderData = object.value as? [String: Any] else {
                    return
                }
                
                //extruder notification contains only one value
                if let extruderTemperature = extruderData["temperature"] {
                    print("temp: \(extruderTemperature)")
                } else if let extruderTarget = extruderData["target"] {
                    print("target: \(extruderTarget)")
                }
            }
        }
    }
}
