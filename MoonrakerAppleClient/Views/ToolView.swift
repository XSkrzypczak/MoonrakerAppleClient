//
//  ToolView.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 05/01/2025.
//

import SwiftUI

struct ToolView: View {
    @EnvironmentObject var printer: Printer
    var body: some View {
        VStack {
            
        }
    }
}

#Preview {
    ToolView()
        .environmentObject(Printer(url: URL(string:"ws://192.168.88.39:7125")!))
}
