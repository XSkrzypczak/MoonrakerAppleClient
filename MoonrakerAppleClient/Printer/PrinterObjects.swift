//
//  PrinterObjects.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 10/11/2024.
//

import Foundation

extension Printer {
    enum KlippyStatus {
        case ready
        case shutdown
        case disconnected
        case null
        
        var description: String {
            switch self {
            case .ready:
                return "Ready"
            case .shutdown:
                return "Shutdown"
            case .disconnected:
                return "Disconnected"
            case .null:
                return "null"
            }
        }
    }
    enum PrinterStatus {
        case standby
        case printing
        case paused
        case complete
        case cancelled
        case error
        case null
        
        var description: String {
            switch self {
            case .standby:
                return "Standby"
            case .printing:
                return "Printing"
            case .paused:
                return "Paused"
            case .complete:
                return "Complete"
            case .cancelled:
                return "Cancelled"
            case .error:
                return "Error"
            case .null:
                return "null"
            }
        }
    }
    
    enum Axis {
        case x
        case y
        case z
        case e
        case xyz
        
        var description: String {
            switch self {
            case .x:
                return "X"
            case .y:
                return "Y"
            case .z:
                return "Z"
            case .e:
                return "E"
            case .xyz:
                return "XYZ"
            }
        }
    }
    
    protocol Heater {
        var name: String { get set }
        var temperature: Double { get set }
        var target: Double { get set }
        var power: Double { get set }
    }
    
    struct Extruder: Heater {
        var name: String = "extruder"
        var canExtrude: Bool = false
        var temperature: Double = 0.0
        var target: Double = 0.0
        var power: Double = 0.0
        var pressureAdvance: Double = 0.0
        var smoothTime: Double = 0.0
    }
    
    struct HeaterBed: Heater {
        var name: String = "heater_bed"
        var temperature: Double = 0.0
        var target: Double = 0.0
        var power: Double = 0.0
    }
    
    struct TemperatureSensor {
        var name: String = ""
        var temperature: Double = 0.0
        var measuredMinTemp: Double = 0.0
        var measuredMaxTemp: Double = 0.0
    }
    
    struct TemperatureFan {
        var name: String = ""
        var speed: Double = 0.0
        var temperature: Double = 0.0
        var target: Double = 0.0
    }
    
    struct HeaterFan {
        var name: String = ""
        var speed: Double = 0.0
        var rpm: Int? = nil
    }
    
    struct Toolhead {
        var extruder: String = ""
        var position: [Axis: Double] = [.x: 0.0, .y: 0.0, .z: 0.0, .e: 0.0]
        var maxVelocity: Double = 0.0
        var maxAccel: Double = 0.0
        var maxAccelToDecel: Double = 0.0
        var squareCornerVelocity: Double = 0.0
        var homedAxes: [Axis: Bool] = [.x: false, .y: false, .z: false]
    }
    
    struct PrintStats {
        var filename: String = ""
        var totalDuration: Double = 0.0
        var printDuration: Double = 0.0
        var filamentUsed: Double = 0.0
        var state: String = ""
        var message: String = ""
        var info: [String: Any?] = ["totalLayer": nil, "currentLayer": nil]
    }
    
    struct GcodeMove {
        var speedFactor: Double = 0.0
        var speed: Double = 0.0
        var extruderFactor: Double = 0.0
        var absoluteCoordinates: Bool = true
        var absoluteExtrude: Bool = false
        var homingOrigin: [Double] = [0.0, 0.0, 0.0, 0.0]
        var position: [Double] = [0.0, 0.0, 0.0, 0.0]
        var gcodePosition: [Double] = [0.0, 0.0, 0.0, 0.0]
    }
    struct FilamentFan {
        var speed: Double = 0.0
        var rpm: Int?
    }
    
    struct GCode: Identifiable {
        var id = UUID()
        let message: String
        let time: Double
        let type: GCodeType
        
        enum GCodeType {
            case command
            case response
            
            var rawValue: String {
                switch self {
                case .command:
                    return "Command"
                case .response:
                    return "Response"
                }
            }
        }
    }
}
