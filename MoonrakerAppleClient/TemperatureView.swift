//
//  TemperatureView.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 26/12/2024.
//

import SwiftUI

struct TemperatureView: View {
    @EnvironmentObject var printer: Printer
    
    var body: some View {
        VStack {
            HStack {
                Text("Heater")
                    .font(.headline)
                    .frame(width: 100)
                Text("Temperature")
                    .frame(width: 100)
                Text("Target")
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .frame(width: 100)
                //Turn off heaters button
                Button(action: {
                    Task {
                        await printer.turnOffHeaters()
                    }
                }) {
                    Image(systemName:"thermometer.snowlake")
                }
            }
            .padding()
            ForEach(printer.extruders, id: \.name) { extruder in
                if let index = printer.extruders.firstIndex(where: { $0.name == extruder.name }) {
                    HeaterBlock(heater: $printer.extruders[index])
                }
            }
            HeaterBlock(heater: $printer.heaterBed)
        }
    }
}

struct HeaterBlock<Heater: Printer.Heater>: View {
    @EnvironmentObject var printer: Printer
    @Binding var heater: Heater
    @State private var target: String = "0"
    @State private var temperature: Double = 0

    var body: some View {
        HStack {
            Text(String(heater.name))
                .font(.headline)
                .frame(width: 100)
            Text(String(heater.temperature))
                .frame(width: 100)
            TextField("0", text: $target)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
                .frame(width: 100)
                .onSubmit {
                    guard let target = Double(target) else { return }
                    Task {
                        await printer.setHeaterTarget(heater, to: target)
                    }
                }
        }
        .padding()
    }
}

#Preview {
    TemperatureView()
        .environmentObject(Printer(url: URL(string: "ws://192.168.88.39:7125")!))
}
