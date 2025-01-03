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
    
    func setHeaterTarget(_ heater: Heater, to target: Double) async {
        await runGCode("SET_HEATER_TEMPERATURE HEATER=\(heater.name) TARGET=\(target)")
    }
    
    func turnOffHeaters() async {
        await runGCode("TURN_OFF_HEATERS")
    }
}
