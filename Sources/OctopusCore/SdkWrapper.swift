//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient

/// A wrapper SDK (Flutter, React Native, Unity) that embeds this native SDK. Native is not a case: it is the
/// default of `SdkIdentityRegistry` and a wrapper cannot declare it.
package enum SdkWrapper: Sendable, CaseIterable {
    case flutter
    case reactNative
    case unity

    var remoteValue: SdkIdentity.Family {
        switch self {
        case .flutter: .flutter
        case .reactNative: .reactNative
        case .unity: .unity
        }
    }
}

extension SdkIdentityRegistry {
    /// Records the wrapper SDK the host app integrates, with the wrapper's own version.
    package func set(wrapper: SdkWrapper, version: String) {
        set(family: wrapper.remoteValue, version: version)
    }
}
