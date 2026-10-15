//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Warning line pinned to the bottom of every host-app screen while the SDK targets a backend feature env.
///
/// Nothing is shown on the default community: the three-tab shell already tells host screens (Scenarios,
/// Settings) from the SDK (Community), so the former "Host app screen" caption only cluttered the tab bar.
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
        // An empty stack takes no height, so the inset is zero on the default community.
        VStack(spacing: 0) {
            if let env = featureEnv {
                // `.caption` rather than a fixed point size, which would ignore Dynamic Type.
                Text("Feature env: \(env.displayName) · \(env.communityName)")
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.warningText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SampleTokens.Spacing.space1)
                    .background(SampleTokens.Colors.warningTint)
                    .accessibilityId("feature-env-footer")
            }
        }
        .onReceive(SDKConfigManager.instance.$sdkConfig) { featureEnv = $0?.featureEnv }
    }
}

extension View {
    /// Pins the feature-env warning line to the bottom of this host screen, when an env is targeted, and puts
    /// the Debug console button in its navigation bar, as every Android tab page carries it. On iOS 15+ the
    /// footer extends the safe area (content sits above it); on older versions it overlays the content.
    ///
    /// - Parameter debugConsole: `false` on a screen that already fills its bar with `navigationBarItems`
    ///   (mixing it with `toolbar` drops items) or that is shown before the tabs exist.
    @ViewBuilder
    func hostAppFooter(debugConsole: Bool = true) -> some View {
        if #available(iOS 15.0, *) {
            safeAreaInset(edge: .bottom, spacing: 0) {
                HostAppFooterView()
            }
            .modifier(DebugConsoleButton(isEnabled: debugConsole))
        } else {
            overlay(HostAppFooterView(), alignment: .bottom)
                .modifier(DebugConsoleButton(isEnabled: debugConsole))
        }
    }
}

/// The trailing bug button of a host page and the Debug console sheet it opens.
private struct DebugConsoleButton: ViewModifier {
    let isEnabled: Bool
    @State private var isPresented = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { isPresented = true }) {
                            Image(systemName: "ladybug")
                        }
                        .accessibilityLabelCompat("Debug console")
                        .accessibilityId("debug-open-button")
                    }
                }
                .sheet(isPresented: $isPresented) { DebugConsoleSheet(isPresented: $isPresented) }
        } else {
            content
        }
    }
}
