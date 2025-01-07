//
//  PrinterCommands.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 26/12/2024.
//

import Foundation

extension Printer {
    func runGCode(_ gcode: String) async {
        do {
            try await sendRequest(method: "printer.gcode.script", params: [Param(key: "script", values: gcode)])
            gcodes.append(GCode(message: gcode, time: Double(Date().timeIntervalSince1970), type: .command))
        } catch {
            print("Error sending GCode: \(error)")
        }
    }
    //convert mm/s to mm/min
    func getFParameter(_ speed: Int) -> Int {
        return speed * 60
    }
    //MARK: Temperature commands
    
    func setHeaterTarget(_ heater: Heater, to target: Double) async {
        await runGCode("SET_HEATER_TEMPERATURE HEATER=\(heater.name) TARGET=\(target)")
    }
    
    func turnOffHeaters() async {
        await runGCode("TURN_OFF_HEATERS")
    }
    
    //MARK: Tool commands
    
    func homeAxis(_ axis: String) async {
        await runGCode("G28 \(axis)")
    }
    
    func homeAllAxes() async {
        await runGCode("G28")
    }
    
    func moveAxisToPosition(axis: String, position: Double, speed: Int) async throws {
        // Check if the axis is homed
        switch axis.lowercased() {
        case "x":
            if !toolhead.homedAxes.x {
                throw NSError(domain: "Printer", code: 99, userInfo: [NSLocalizedDescriptionKey: "Axis X is not homed"])
            }
        case "y":
            if !toolhead.homedAxes.y {
                throw NSError(domain: "Printer", code: 99, userInfo: [NSLocalizedDescriptionKey: "Axis Y is not homed"])
            }
        case "z":
            if !toolhead.homedAxes.z {
                throw NSError(domain: "Printer", code: 99, userInfo: [NSLocalizedDescriptionKey: "Axis Z is not homed"])
            }
        default:
            throw NSError(domain: "Printer", code: 98, userInfo: [NSLocalizedDescriptionKey: "Unknown axis \(axis)"])
        }
        
        await runGCode("G1 \(axis)\(position) F\(getFParameter(speed))")
    }

    
    func moveAxisRelative(axis: String, distance: Double, speed: Int) async throws {
        switch axis.lowercased() {
        case "x":
            if !toolhead.homedAxes.x {
                throw NSError(domain: "Printer", code: 99, userInfo: [NSLocalizedDescriptionKey: "Axis X is not homed"])
            }
        case "y":
            if !toolhead.homedAxes.y {
                throw NSError(domain: "Printer", code: 99, userInfo: [NSLocalizedDescriptionKey: "Axis Y is not homed"])
            }
        case "z":
            if !toolhead.homedAxes.z {
                throw NSError(domain: "Printer", code: 99, userInfo: [NSLocalizedDescriptionKey: "Axis Z is not homed"])
            }
        default:
            throw NSError(domain: "Printer", code: 98, userInfo: [NSLocalizedDescriptionKey: "Unknown axis \(axis)"])
        }
        //relative positioning
        await runGCode("G91")
        await runGCode("G1 \(axis)\(distance) F\(getFParameter(speed))")
        //reset to absolute positioning
        await runGCode("G90")
    }
    
    func turnOffMotors() async {
        await runGCode("M84")
    }
    
    func adjustZOffset(_ offset: Double, positive: Bool, moveTool: Bool = true) async {
        await runGCode("SET_GCODE_OFFSET Z_ADJUST=\(positive ? "+" : "-")\(offset) MOVE_TOOL=\(moveTool ? "1" : "0")")
    }
    
    func saveZOFfset() async {
        await runGCode("Z_OFFSET_APPLY_ENDSTOP")
    }
    
    func extrude(_ distance: Int, speed: Int) async throws {
        if extruders.first(where: { $0.name == toolhead.extruder })?.canExtrude == true {
            await runGCode("M83")
            await runGCode("G1 E\(distance) F\(getFParameter(speed))")
        } else {
            throw NSError(domain: "Printer.Extruder", code: 100, userInfo: [NSLocalizedDescriptionKey: "Extruder \(toolhead.extruder) cannot extrude"])
        }
        
    }
}
