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
    struct Extruder {
        var temperature: Double = 0.0
        var target: Double = 0.0
        var power: Double = 0.0
        var pressureAdvance: Double = 0.0
        var smoothTime: Double = 0.0
    }
    
    struct HeaterBed {
        var temperature: Double = 0.0
        var target: Double = 0.0
        var power: Double = 0.0
    }
    
    struct Toolhead {
        var homedAxes: homedAxes = homedAxes()
        var extruder: String = ""
        var position: [Double] = []
        var maxVelocity: Double = 0.0
        var maxAccel: Double = 0.0
        var maxAccelToDecel: Double = 0.0
        var squareCornerVelocity: Double = 0.0
        
        struct homedAxes {
            var x: Bool = false
            var y: Bool = false
            var z: Bool = false
        }
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
        var rpm: Double?
    }
}
