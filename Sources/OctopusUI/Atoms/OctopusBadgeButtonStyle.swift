//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct OctopusBadgeButtonStyle: ButtonStyle {
    @Environment(\.octopusTheme) private var theme

    let kind: OctopusBadgeStyle.Kind
    let status: OctopusBadgeStyle.Status

    init(_ kind: OctopusBadgeStyle.Kind, status: OctopusBadgeStyle.Status) {
        self.kind = kind
        self.status = status
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .octopusBadgeStyle(kind, status: status)
    }
}

#Preview {
    VStack {
        HStack {
            Text("Medium On")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusBadgeButtonStyle(.medium, status: .on))
        }

        HStack {
            Text("Medium Off")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusBadgeButtonStyle(.medium, status: .off))
        }

        HStack {
            Text("Small On")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusBadgeButtonStyle(.small, status: .on))
        }

        HStack {
            Text("Small Off")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusBadgeButtonStyle(.small, status: .off))
        }

        HStack {
            Text("Small Warning")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusBadgeButtonStyle(.small, status: .warning))
        }

        HStack {
            Text("Small Admin")
            Spacer()
            Button(action: {}) {
                Text("Admin")
            }.buttonStyle(OctopusBadgeButtonStyle(.small, status: .admin))
        }
    }
    .padding()
}
