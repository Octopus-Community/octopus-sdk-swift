//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// This namespace provides default values for the sample according to the keys that are provided.
/// This is usefull to make it easy your discovery of the Samples
enum DefaultValuesProvider {
    /// Whether the app is in demo mode (internal tests only).
    static let internalDemoMode = !(Bundle.main.infoDictionary?["OCTOPUS_INTERNAL_DEMO_MODE"] as? String ?? "").isEmpty
}
