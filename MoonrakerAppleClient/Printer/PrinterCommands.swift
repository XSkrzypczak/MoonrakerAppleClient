//
//  PrinterCommands.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 26/12/2024.
//

import Foundation

@MainActor
extension Printer {
    func runGCode(_ gcode: String) async {
        do {
            let response = try await getRequest(method: "printer.gcode.script", params: [Param(key: "script", values: gcode)]).value
            print(response)
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
    
    func homeAxis(_ axis: Axis) async {
        if axis == .x || axis == .y || axis == .z {
            await runGCode("G28 \(axis.description)")
        } else if axis == .xyz {
            await runGCode("G28")
        }
    }
    
    func moveAxisToPosition(axis: Axis, position: Double, speed: Int) async {
        // Check if the axis is homed
        if toolhead.homedAxes[axis] == false { return }
        
        await runGCode("G1 \(axis.description)\(position) F\(getFParameter(speed))")
    }

    
    func moveAxisRelative(axis: Axis, distance: Double, speed: Int) async {
        if toolhead.homedAxes[axis] == false { return }
        //relative positioning
        await runGCode("G91")
        await runGCode("G1 \(axis.description)\(distance) F\(getFParameter(speed))")
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
