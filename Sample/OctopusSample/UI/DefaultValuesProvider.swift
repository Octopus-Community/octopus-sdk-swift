//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// This namespace provides default values for the sample according to the keys that are provided.
/// This is usefull to make it easy your discovery of the Samples
enum DefaultValuesProvider {
    /// Whether the app is in demo mode (internal tests only).
    static let internalDemoMode = !(Bundle.main.infoDictionary?["OCTOPUS_INTERNAL_DEMO_MODE"] as? String ?? "").isEmpty

    /// Host of the internal feature-env directory, without its scheme (an xcconfig would read `//` as the
    /// start of a comment). Empty when not configured.
    static let featureEnvsHost = Bundle.main.infoDictionary?["OCTOPUS_FEATURE_ENVS_HOST"] as? String ?? ""

    /// Token of the internal feature-env directory. Never log this value.
    static let featureEnvsToken = Bundle.main.infoDictionary?["OCTOPUS_FEATURE_ENVS_TOKEN"] as? String ?? ""

    /// Whether the feature-env picker can work. When false, the scenario is hidden entirely.
    static var featureEnvsConfigured: Bool { !featureEnvsHost.isEmpty && !featureEnvsToken.isEmpty }

    /// Ticket (or env name) passed at launch to target a feature env without touching the UI:
    /// `xcrun simctl launch <udid> com.octopuscommunity.sdk.sample -featureEnvTicket OCT-1707`.
    /// `UserDefaults` exposes `-key value` launch arguments, which is what QA tooling uses.
    static var featureEnvTicketArgument: String? { launchArgument("featureEnvTicket") }

    /// Optional community id or name fragment, when an env has several and the first one is not the
    /// wanted one: `-featureEnvCommunity "Pictures Off"`.
    static var featureEnvCommunityArgument: String? { launchArgument("featureEnvCommunity") }

    private static func launchArgument(_ key: String) -> String? {
        guard let value = UserDefaults.standard.string(forKey: key), !value.isEmpty else { return nil }
        return value
    }
}
