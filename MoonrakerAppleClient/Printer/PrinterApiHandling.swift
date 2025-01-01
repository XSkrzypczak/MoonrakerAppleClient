//
//  PrinterApiHandling.swift
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
            guard let printerObjects = try await getRequest(method: "printer.objects.list").value as? [String: Any] else {
                throw NSError(domain: "PrinterClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get printer objects"])
            }
            self.printerObjects = printerObjects["objects"] as! [String]
            for object in self.printerObjects {
                if object.hasPrefix("extruder") {
                    if !self.extruders.contains(where: { $0.name == object }) {
                        self.extruders.append(Extruder(name: object))
                    }
                } else if object.hasPrefix("temperature_sensor") {
                    let name = String(object.split(separator: " ")[1])
                    if !self.temperatureSensors.contains(where: { $0.name == name }) {
                        self.temperatureSensors.append(TemperatureSensor(name: name))
                    }
                } else if object.hasPrefix("temperature_fan") {
                    let name = String(object.split(separator: " ")[1])
                    if !self.temperatureFans.contains(where: { $0.name == name }) {
                        self.temperatureFans.append(TemperatureFan(name: name))
                    }
                } else if object.hasPrefix("heater_fan") {
                    let name = String(object.split(separator: " ")[1])
                    if !self.heaterFans.contains(where: { $0.name == name }) {
                        self.heaterFans.append(HeaterFan(name: name))
                    }
                } else if object.hasPrefix("gcode_macro") {
                    let name = String(object.split(separator: " ")[1])
                    if !self.gcodeMacros.contains(where: { $0 == name }) {
                        self.gcodeMacros.append(name)
                    }
                }
            }
            
            //get response as dictionary
            guard let printerInfo = try await getRequest(method: "printer.info").value as? [String: Any] else {
                throw NSError(domain: "PrinterClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get printer info"])
            }
            //decode response to PrinterInfo
            let state: KlippyStatus = {
                switch printerInfo["state"] as? String {
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
            self.stateMessage = printerInfo["state_message"] as? String ?? ""
            
            guard let storedGcodesResponse = try await getRequest(method: "server.gcode_store", params: [Param(key: "count", values: 100)]).value as? [String: Any] else {
                throw NSError(domain: "PrinterClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get stored gcodes"])
            }
            if let storedGcodes = storedGcodesResponse["gcode_store"] as? [[String: Any]] {
                
                for gcode in storedGcodes {
                    guard let message = gcode["message"] as? String,
                          let time = gcode["time"] as? Double,
                          let type = gcode["type"] as? String else { return }
                    
                    let gcode = GCode(message: message, time: time, type: type == "command" ? .command : .response)
                    self.gcodes.append(gcode)
                }
            }
            
        } catch {
            throw error
        }
    }
    
    func statusUpdateSubscribe() async {
        //TODO: Get available objects from api
        let response = try? await getRequest(method: "printer.objects.subscribe", params: [Param(
            key: "objects",
            values: [
                "extruder": nil,
                "toolhead": nil,
                "heater_bed": nil,
                "fan": nil,
                "print_stats": nil,
                "gcode_move": nil
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
            if let extruderIndex = self.extruders.firstIndex(where: { $0.name == object.key }) {
                guard let extruderData = object.value as? [String: Any] else { continue }
                DispatchQueue.main.async {
                    if let extruderTemperature = extruderData["temperature"] {
                        self.extruders[extruderIndex].temperature = getDoubleValue(extruderTemperature)
                    }
                    if let extruderTarget = extruderData["target"] {
                        self.extruders[extruderIndex].target = getDoubleValue(extruderTarget)
                    }
                    if let extruderPower = extruderData["power"] {
                        self.extruders[extruderIndex].power = getDoubleValue(extruderPower)
                    }
                }
            } else if object.key == "heater_bed" {
                guard let heaterBedData = object.value as? [String: Any] else {
                    return
                }
                DispatchQueue.main.async {
                    if let heaterBedTemperature = heaterBedData["temperature"] {
                        self.heaterBed.temperature = getDoubleValue(heaterBedTemperature)
                    }
                    if let heaterBedTarget = heaterBedData["target"] {
                        self.heaterBed.target = getDoubleValue(heaterBedTarget)
                    }
                    
                    if let heaterBedPower = heaterBedData["power"] {
                        self.heaterBed.power = getDoubleValue(heaterBedPower)
                    }
                }
            } else if object.key == "print_stats" {
                guard let printStats = object.value as? [String: Any] else {
                    return
                }
                DispatchQueue.main.async {
                    if let printFilename = printStats["filename"] as? String {
                        self.printStats.filename = printFilename
                    }
                    if let printDuration = printStats["print_duration"] as? Double {
                        self.printStats.printDuration = getDoubleValue(printDuration)
                    }
                    if let printState = printStats["state"] as? String {
                        switch printState {
                        case "standby":
                            self.printerStatus = .standby
                        case "printing":
                            self.printerStatus = .printing
                        case "paused":
                            self.printerStatus = .paused
                        case "complete":
                            self.printerStatus = .complete
                        case "cancelled":
                            self.printerStatus = .cancelled
                        case "error":
                            self.printerStatus = .error
                        default:
                            self.printerStatus = .null
                        }
                    }
                    if let totalDuration = printStats["total_duration"] {
                        self.printStats.printDuration = getDoubleValue(totalDuration)
                    }
                    if let filamentUsed = printStats["filament_used"] {
                        self.printStats.filamentUsed = getDoubleValue(filamentUsed)
                    }
                    if let state = printStats["state"] as? String {
                        self.printStats.state = state
                    }
                    if let message = printStats["message"] as? String {
                        self.printStats.message = message
                    }
                    if let info = printStats["info"] as? [String: Any?] {
                        self.printStats.info = info
                    }
                }
            } else if object.key == "toolhead" {
                guard let toolheadData = object.value as? [String: Any] else {
                    return
                }
                DispatchQueue.main.async {
                    if let homedAxesString = toolheadData["homed_axes"] as? String {
                        let homedAxes = homedAxesString.map { String($0.lowercased()) }
                        self.toolhead.homedAxes.x = false
                        self.toolhead.homedAxes.y = false
                        self.toolhead.homedAxes.z = false
                        for axis in homedAxes {
                            switch axis {
                            case "x":
                                self.toolhead.homedAxes.x = true
                            case "y":
                                self.toolhead.homedAxes.y = true
                            case "z":
                                self.toolhead.homedAxes.z = true
                            default:
                                break
                            }
                        }
                    }
                    if let extruder = toolheadData["extruder"] as? String {
                        self.toolhead.extruder = extruder
                    }
                    if let position = toolheadData["position"] as? [Any] {
                        self.toolhead.position = convertToDoubleArray(position)
                    }
                    if let maxVelocity = toolheadData["max_velocity"] {
                        self.toolhead.maxVelocity = getDoubleValue(maxVelocity)
                    }
                    if let maxAccel = toolheadData["max_accel"] {
                        self.toolhead.maxAccel = getDoubleValue(maxAccel)
                    }
                    if let maxAccelToDecel = toolheadData["max_accel_to_decel"] {
                        self.toolhead.maxAccelToDecel = getDoubleValue(maxAccelToDecel)
                    }
                    if let squareCornerVelocity = toolheadData["square_corner_velocity"] {
                        self.toolhead.squareCornerVelocity = getDoubleValue(squareCornerVelocity)
                    }
                }
            } else if object.key == "gcode_move" {
                guard let gcodeMoveData = object.value as? [String: Any] else {
                    return
                }
                DispatchQueue.main.async {
                    if let speedFactor = gcodeMoveData["speed_factor"] {
                        self.gcodeMove.speedFactor = getDoubleValue(speedFactor)
                    }
                    if let speed = gcodeMoveData["speed"] {
                        self.gcodeMove.speed = getDoubleValue(speed)
                    }
                    if let extrudeFactor = gcodeMoveData["extrude_factor"] {
                        self.gcodeMove.extruderFactor = getDoubleValue(extrudeFactor)
                    }
                    if let absoluteCoordinates = gcodeMoveData["absolute_coordinates"] as? Bool {
                        self.gcodeMove.absoluteCoordinates = absoluteCoordinates
                    }
                    if let absoluteExtrude = gcodeMoveData["absolute_extrude"] as? Bool {
                        self.gcodeMove.absoluteExtrude = absoluteExtrude
                    }
                    if let homingOrigin = gcodeMoveData["homing_origin"] as? [Any] {
                        self.gcodeMove.homingOrigin = convertToDoubleArray(homingOrigin)
                    }
                    if let position = gcodeMoveData["position"] as? [Any] {
                        self.gcodeMove.position = convertToDoubleArray(position)
                    }
                    if let gcodePosition = gcodeMoveData["gcode_position"] as? [Any] {
                        self.gcodeMove.gcodePosition = convertToDoubleArray(gcodePosition)
                    }
                }
            } else if object.key == "fan" {
                guard let fanData = object.value as? [String: Any] else {
                    return
                }
                DispatchQueue.main.async {
                    if let speed = fanData["speed"] {
                        self.filamentFan.speed = getDoubleValue(speed)
                    }
                    if let rpm = fanData["rpm"] {
                        self.filamentFan.rpm = rpm as? Int
                    }
                }
            }
            //avoid getting values from responses in int
            func getDoubleValue(_ value: Any?) -> Double {
                if let doubleValue = value as? Double {
                    return doubleValue
                } else if let intValue = value as? Int {
                    return Double(intValue)
                }
                return 0.0
            }
            func convertToDoubleArray(_ input: [Any]) -> [Double] {
                return input.compactMap { element in
                    if let doubleValue = element as? Double {
                        return doubleValue
                    } else if let intValue = element as? Int {
                        return Double(intValue)
                    }
                    return nil
                }
            }
        }
    }
}
