//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusUI
import Octopus
import OctopusCore

/// Root view of the sample. In non-internal demo mode, it will display directly the SampleTabView
struct SampleRootView: View {
    @State private var displaySDKConfig = DefaultValuesProvider.internalDemoMode && SDKConfigManager.instance.sdkConfig == nil
    @State private var featureEnvLaunchArgumentHandled = false

    var body: some View {
        Group {
            if displaySDKConfig {
                SDKConfigScreen()
            } else {
                SampleTabView()
            }
        }
        .onReceive(SDKConfigManager.instance.$sdkConfig) {
            displaySDKConfig = DefaultValuesProvider.internalDemoMode && $0 == nil
            applyFeatureEnvLaunchArgumentIfPossible(config: $0)
        }
    }

    /// Applies the `-featureEnvTicket` launch argument (QA tooling, CLI runs), once, as soon as a config
    /// exists to switch.
    ///
    /// Deliberately here rather than in `AppDelegate`: reaching for `OctopusSDKProvider.instance` before
    /// any UI has run builds the SDK from a config that does not exist yet, which aborts the app in
    /// internal demo mode. Waiting for a non-nil config also means the argument still works on a fresh
    /// install — it applies right after the developer picks a config, instead of being dropped.
    private func applyFeatureEnvLaunchArgumentIfPossible(config: SDKConfig?) {
        guard !featureEnvLaunchArgumentHandled,
              config != nil,
              DefaultValuesProvider.internalDemoMode,
              DefaultValuesProvider.featureEnvTicketArgument != nil else { return }
        featureEnvLaunchArgumentHandled = true
        OctopusSDKProvider.instance.applyFeatureEnvFromLaunchArgumentIfNeeded()
    }
}
