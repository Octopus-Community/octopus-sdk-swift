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
            Text(verbatim: "Medium On")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusBadgeButtonStyle(.medium, status: .on))
        }

        HStack {
            Text(verbatim: "Medium Off")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusBadgeButtonStyle(.medium, status: .off))
        }

        HStack {
            Text(verbatim: "Small On")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusBadgeButtonStyle(.small, status: .on))
        }

        HStack {
            Text(verbatim: "Small Off")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusBadgeButtonStyle(.small, status: .off))
        }

        HStack {
            Text(verbatim: "Small Warning")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusBadgeButtonStyle(.small, status: .warning))
        }

        HStack {
            Text(verbatim: "Small Admin")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Admin")
            }.buttonStyle(OctopusBadgeButtonStyle(.small, status: .admin))
        }
    }
    .padding()
}
