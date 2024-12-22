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
    func statusUpdateSubscribe() async {
        let response = try? await getRequest(method: "printer.objects.subscribe", params: [Param(
            key: "objects",
            values: [
                "extruder": nil,
                "heater_bed": nil,
                "fan": nil,
                "print_stats": nil
            ]
        )])
            .value as? [String: Any]
        
        guard let objects = response?["status"] as? [String: Any] else {
            return
        }
        
        setPrinterObjectsValues(objects)
    }
    
    func handleStatusUpdate(_ notification: Any?) {
        //get array of objects from status update
        guard let response = notification as? [Any],
              let objects = response.first as? [String: Any] else {
            return
        }
        
        setPrinterObjectsValues(objects)
        
    }
    
    func setPrinterObjectsValues(_ objects: [String: Any]) {
        for object in objects {
            if object.key == "extruder" {
                guard let extruderData = object.value as? [String: Any] else {
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    if let extruderTemperature = extruderData["temperature"] {
                        self?.extruder.temperature = getDoubleValue(extruderTemperature)
                    }
                    if let extruderTarget = extruderData["target"] {
                        self?.extruder.target = getDoubleValue(extruderTarget)
                    }
                    if let extruderPower = extruderData["power"] {
                        self?.extruder.power = getDoubleValue(extruderPower)
                    }
                }
            } else if object.key == "heater_bed" {
                guard let heaterBedData = object.value as? [String: Any] else {
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    if let heaterBedTemperature = heaterBedData["temperature"]{
                        self?.heaterBed.temperature = getDoubleValue(heaterBedTemperature)
                    }
                    if let heaterBedTarget = heaterBedData["target"] {
                        self?.heaterBed.target = getDoubleValue(heaterBedTarget)
                    }

                    if let heaterBedPower = heaterBedData["power"] {
                        self?.heaterBed.power = getDoubleValue(heaterBedPower)
                    }
                }
            } else if object.key == "print_stats" {
                guard let printStats = object.value as? [String: Any] else {
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    //check if file is loaded
                    if let printFilename = printStats["filename"] as? String {
                        self?.printStats.filename = printFilename
                        if let printDuration = printStats["print_duration"] as? Double {
                            self?.printStats.printDuration = getDoubleValue(printDuration)
                        }
                        if let printState = printStats["state"] as? String {
                            switch printState {
                            case "standby":
                                self?.printerStatus = .standby
                            case "printing":
                                self?.printerStatus = .printing
                            case "paused":
                                self?.printerStatus = .paused
                            case "complete":
                                self?.printerStatus = .complete
                            case "cancelled":
                                self?.printerStatus = .cancelled
                            case "error":
                                self?.printerStatus = .error
                            default:
                                self?.printerStatus = .null
                            }
                        }
                        if let totalDuration = printStats["total_duration"] as? Double {
                            self?.printStats.printDuration = getDoubleValue(totalDuration)
                        }
                        if let filamentUsed = printStats["filament_used"] as? Double {
                            self?.printStats.filamentUsed = getDoubleValue(filamentUsed)
                        }
                        if let state = printStats["state"] as? String {
                            self?.printStats.state = state
                        }
                        if let message = printStats["message"] as? String {
                            self?.printStats.message = message
                        }
                        if let info = printStats["info"] as? [String: Any?] {
                            self?.printStats.info = info
                        }
                    }
                }
            } else if object.key == "toolhead" {
                guard let toolheadData = object.value as? [String: Any] else {
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    if let homedAxesString = toolheadData["homed_axes"] as? String {
                        let homedAxes = homedAxesString.map { String($0.lowercased()) }
                        self?.toolhead.homedAxes.x = false
                        self?.toolhead.homedAxes.y = false
                        self?.toolhead.homedAxes.z = false
                        for axis in homedAxes {
                            switch axis {
                            case "x":
                                self?.toolhead.homedAxes.x = true
                            case "y":
                                self?.toolhead.homedAxes.y = true
                            case "z":
                                self?.toolhead.homedAxes.z = true
                            default:
                                break
                            }
                        }
                    }
                    if let extruder = toolheadData["extruder"] as? String {
                        self?.toolhead.extruder = extruder
                    }
                    if let position = toolheadData["position"] as? [Double] {
                        self?.toolhead.position = position
                    }
                    if let maxVelocity = toolheadData["max_velocity"] as? Double {
                        self?.toolhead.maxVelocity = maxVelocity
                    }
                    if let maxAccel = toolheadData["max_accel"] as? Double {
                        self?.toolhead.maxAccel = maxAccel
                    }
                    if let maxAccelToDecel = toolheadData["max_accel_to_decel"] as? Double {
                        self?.toolhead.maxAccelToDecel = maxAccelToDecel
                    }
                    if let squareCornerVelocity = toolheadData["square_corner_velocity"] as? Double {
                        self?.toolhead.squareCornerVelocity = squareCornerVelocity
                    }
                }
            }
            //avoid getting default values from responses in int
            func getDoubleValue(_ value: Any?) -> Double {
                if let doubleValue = value as? Double {
                    return doubleValue
                } else if let intValue = value as? Int {
                    return Double(intValue)
                }
                return 0.0
            }
        }
    }
}
