//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Small caption shown at the bottom of every host-app screen so it's easy to tell at a
/// glance which screens come from the sample (host) app vs. the Octopus SDK UI.
struct HostAppFooterView: View {
    var body: some View {
        Text("Host app screen")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(Color(.systemGroupedBackground))
    }
}

extension View {
    /// Pins a small "Host app screen" caption to the bottom of this view so the tester can
    /// immediately see when they're looking at host-app UI vs. SDK UI. On iOS 15+ the footer
    /// extends the safe area (content sits above it); on older versions it overlays the
    /// content as a fallback.
    @ViewBuilder
    func hostAppFooter() -> some View {
        if #available(iOS 15.0, *) {
            safeAreaInset(edge: .bottom, spacing: 0) {
                HostAppFooterView()
            }
        } else {
            overlay(HostAppFooterView(), alignment: .bottom)
        }
    }
}
