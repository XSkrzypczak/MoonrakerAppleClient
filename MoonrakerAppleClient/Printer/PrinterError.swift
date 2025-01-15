//
//  PrinterError.swift
//  MoonrakerAppleClient
//
//  Created by Mikolaj Skrzypczak on 14/01/2025.
//

import SwiftUI

extension Printer {
    struct PrinterError: Identifiable {
        let id: UUID = UUID()
        let domain: String
        let message: String
    }
    
    struct ErrorPopup: View {
        let domain: String
        let message: String
        var dismiss: () -> Void = { }
        
        var body: some View {
            VStack {
                Text(domain)
                    .font(.headline)
                    .padding()
                Text(message)
                    .padding()
                Button("Close") {
                    withAnimation {
                        dismiss() // Notify the parent to dismiss the popup
                    }
                }
            }
            .frame(width: 250, height: 200)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 10)
        }
    }
    
    func throwError(_ error: PrinterError) {
        errors.append(error)
    }
    
    func dismissErrorPopup(_ error: PrinterError) {
        if let index = errors.firstIndex(where: { $0.id == error.id }) {
            errors.remove(at: index)
        }
    }
    
}

#Preview {
    Printer.ErrorPopup(domain: "Domain", message: "Message")
}
