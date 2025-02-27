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
        do {
            try await fetchPrinterInfo()
            
            var objectsToSubscribe: [String] = []

            // Adding keys
            objectsToSubscribe.append("toolhead")
            objectsToSubscribe.append("gcode_move")

            if printerObjects.contains("virtual_sdcard") {
                objectsToSubscribe.append("print_stats")
            }
            if printerObjects.contains("display") || printerObjects.contains("display_status") {
                objectsToSubscribe.append("display_status")
            }
            if printerObjects.contains("heater_bed") {
                objectsToSubscribe.append("heater_bed")
            }
            if printerObjects.contains("fan") {
                objectsToSubscribe.append("fan")
            }
            for object in printerObjects.filter({ $0.hasPrefix("extruder") }) {
                objectsToSubscribe.append(object)
            }
            for object in printerObjects.filter({ $0.hasPrefix("temperature_fan") }) {
                objectsToSubscribe.append(object)
            }
            for object in printerObjects.filter({ $0.hasPrefix("temperature_sensor") }) {
                objectsToSubscribe.append(object)
            }
            for object in printerObjects.filter({ $0.hasPrefix("heater_fan") }) {
                objectsToSubscribe.append(object)
            }
            
            let response = try? await getRequest(method: "printer.objects.subscribe", params: [Param(
                key: "objects",
                //convert to [String: nil]
                values: Dictionary(uniqueKeysWithValues: objectsToSubscribe.map { ($0, nil as Any?) })
            )])
                .value as? [String: Any]
            
            guard let objects = response?["status"] as? [String: Any] else {
                return
            }
            
            setPrinterObjectsValues(objects)
        } catch {
            print(error)
        }
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
                guard let extruderData = object.value as? [String: Any] else { return }
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
                    if let extruderCanExtrude = extruderData["can_extrude"] as? Bool {
                        self.extruders[extruderIndex].canExtrude = extruderCanExtrude
                    }
                }
            } else if object.key.hasPrefix("heater_fan") {
                let heaterFanName = String(object.key.split(separator: " ")[1])
                if heaterFans.contains(where: { $0.name == heaterFanName }) {
                    guard let heaterFanData = object.value as? [String: Any],
                          let index = heaterFans.firstIndex(where: {$0.name == heaterFanName}) else { return }
                    DispatchQueue.main.async {
                        if let speed = heaterFanData["speed"] {
                            self.heaterFans[index].speed = getDoubleValue(speed)
                        }
                        if let rpm = heaterFanData["rpm"] as? Int {
                            self.heaterFans[index].rpm = rpm
                        }
                    }
                }
            } else if object.key.hasPrefix("heater_fan") {
                let heaterFanName = String(object.key.split(separator: " ")[1])
                if heaterFans.contains(where: { $0.name == heaterFanName }) {
                    guard let heaterFanData = object.value as? [String: Any],
                          let index = heaterFans.firstIndex(where: {$0.name == heaterFanName}) else { return }
                    DispatchQueue.main.async {
                        if let speed = heaterFanData["speed"] {
                            self.heaterFans[index].speed = getDoubleValue(speed)
                        }
                        if let rpm = heaterFanData["rpm"] as? Int {
                            self.heaterFans[index].rpm = rpm
                        }
                    }
                }
            } else if object.key.hasPrefix("temperature_fan") {
                let temperatureFanName = String(object.key.split(separator: " ")[1])
                if temperatureFans.contains(where: { $0.name == temperatureFanName }) {
                    guard let temperatureFanData = object.value as? [String: Any],
                          let index = temperatureFans.firstIndex(where: {$0.name == temperatureFanName}) else { return }
                    DispatchQueue.main.async {
                        if let speed = temperatureFanData["speed"] {
                            self.temperatureFans[index].speed = getDoubleValue(speed)
                        }
                        if let target = temperatureFanData["target"] {
                            self.temperatureFans[index].target = getDoubleValue(target)
                        }
                        if let temperature = temperatureFanData["temperature"] {
                            self.temperatureFans[index].temperature = getDoubleValue(temperature)
                        }
                    }
                }
            } else if object.key.hasPrefix("temperature_sensor") {
                let temperatureSensorName = String(object.key.split(separator: " ")[1])
                if temperatureSensors.contains(where: { $0.name == temperatureSensorName }) {
                    guard let temperatureSensorData = object.value as? [String: Any],
                          let index = temperatureSensors.firstIndex(where: {$0.name == temperatureSensorName}) else { return }
                    DispatchQueue.main.async {
                        if let temperature = temperatureSensorData["temperature"] {
                            self.temperatureSensors[index].temperature = getDoubleValue(temperature)
                        }
                        if let measuredMin = temperatureSensorData["measured_min_temp"] {
                            self.temperatureSensors[index].measuredMinTemp = getDoubleValue(measuredMin)
                        }
                        if let measuredMax = temperatureSensorData["measured_max_temp"] {
                            self.temperatureSensors[index].measuredMaxTemp = getDoubleValue(measuredMax)
                        }
                    }
                }
            }
            
            else if object.key == "heater_bed" {
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
                        let homedAxes: [Axis] = homedAxesString.compactMap { character in
                            switch character.lowercased() {
                            case "x": return .x
                            case "y": return .y
                            case "z": return .z
                            case "e": return .e
                            default: return nil // Ignore invalid characters
                            }
                        }
                        self.toolhead.homedAxes[.x] = false
                        self.toolhead.homedAxes[.y] = false
                        self.toolhead.homedAxes[.z] = false
                        for axis in homedAxes {
                            self.toolhead.homedAxes[axis] = true
                        }
                    }
                    if let extruder = toolheadData["extruder"] as? String {
                        self.toolhead.extruder = extruder
                    }
                    if let position = toolheadData["position"] as? [Any] {
                        self.toolhead.position[.x] = getDoubleValue(position[0])
                        self.toolhead.position[.y] = getDoubleValue(position[1])
                        self.toolhead.position[.z] = getDoubleValue(position[2])
                        self.toolhead.position[.e] = getDoubleValue(position[3])
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
