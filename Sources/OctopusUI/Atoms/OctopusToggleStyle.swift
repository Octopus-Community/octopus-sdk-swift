//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Toggle switch from Octopus Design System
struct OctopusToggleStyle: ToggleStyle {
    @Environment(\.octopusTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            RoundedRectangle(cornerRadius: 30)
                .fill(configuration.isOn ? theme.colors.primary : theme.colors.gray300)
                .overlay(
                    Image(configuration.isOn ? .Toggle.on : .Toggle.off)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(2)
                        .background(Circle().fill(theme.colors.gray100))
                        .foregroundColor(configuration.isOn ? theme.colors.primary : theme.colors.gray700)
                        .padding(4)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .frame(width: 50, height: 28)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

extension ToggleStyle where Self == OctopusToggleStyle {
    /// Toggle switch from Octopus Design System
    static var octopus: OctopusToggleStyle { .init() }
}
