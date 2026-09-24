//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Small caption shown at the bottom of every host-app screen so it's easy to tell at a
/// glance which screens come from the sample (host) app vs. the Octopus SDK UI.
struct HostAppFooterView: View {
    /// The targeted feature env, so it is impossible to believe you are testing on the default community
    /// while the SDK talks to an env.
    ///
    /// Read from `SDKConfigManager`, deliberately NOT from `OctopusSDKProvider`: this footer sits on
    /// *every* host screen — including `SDKConfigView`, the screen shown when no config exists yet.
    /// Referencing `OctopusSDKProvider.instance` in a stored property would force the singleton's `init`
    /// as soon as that view is constructed, and in internal demo mode that init aborts on
    /// `fatalError("SDK config should be set…")` — the very config the screen exists to create. The
    /// persisted selection carries the same value: a selection dropped at launch is cleared from the
    /// config at the same time.
    @State private var featureEnv: FeatureEnvSelection?

    var body: some View {
        VStack(spacing: 0) {
            Text("Host app screen")
                .font(.caption)
                .foregroundColor(.secondary)
            if let env = featureEnv {
                // `.caption` rather than a fixed `.system(size: 11)`: a hardcoded point size ignores
                // Dynamic Type. (`.caption2`, which would be a size smaller, is iOS 14+ and the Sample
                // targets iOS 13.) The colour is what sets this line apart from the one above.
                Text("Feature env: \(env.displayName) · \(env.communityName)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color(.systemGroupedBackground))
        .onReceive(SDKConfigManager.instance.$sdkConfig) { featureEnv = $0?.featureEnv }
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
