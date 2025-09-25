//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that shows how to track custom events.
struct CustomEventsView: View {
    @StateObjectCompat private var viewModel = OctopusAuthSDKViewModel()

    @State private var success = false

    var body: some View {
        VStack(spacing: 30) {
            Button(action: {
                Task {
                    try await viewModel.octopus?.track(customEvent: CustomEvent(name: "CustomEvent1"))
                    success = true
                }
            }) {
                Text("Send CustomEvent1")
            }

            Button(action: {
                Task {
                    try await viewModel.octopus?.track(customEvent: CustomEvent(
                        name: "Purchase",
                        properties: [
                            "price": .init(value: "\(String(format: "%.2f", Double.random(in: 0..<100)))"),
                            "currency": .init(value: "EUR"),
                            "product_id": .init(value: "\(["u123", "u231", "u312"].randomElement()!)"),
                        ]))
                    success = true
                }
            }) {
                Text("Send Purchase event")
            }
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text(verbatim: "Event successfully tracked"),
                    isPresented: $success, actions: { })
            } else {
                $0.alert(isPresented: $success) {
                    Alert(title: Text(verbatim: "Event successfully tracked"))
                }
            }
        }
    }
}


