//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// The SDK families a wrapper can declare. Native is the default and cannot be set.
///
/// Hidden behind SPI: it is **not** part of the supported public API. Only the Octopus wrapper SDKs opt in
/// with `@_spi(OctopusWrapper) import Octopus`.
@_spi(OctopusWrapper)
public enum OctopusSDKFamily: Sendable, CaseIterable {
    /// The Octopus SDK for Flutter.
    case flutter
    /// The Octopus SDK for React Native.
    case reactNative
    /// The Octopus SDK for Unity.
    case unity

    var coreValue: SdkWrapper {
        switch self {
        case .flutter: .flutter
        case .reactNative: .reactNative
        case .unity: .unity
        }
    }
}

extension OctopusSDK {
    /// Declares the wrapper SDK the host app integrates, so the backend can tell it apart from a native
    /// integration. Without this call the SDK reports itself as native, with its own version.
    ///
    /// Call it before creating `OctopusSDK`. The value is read on every network call, so a later call applies
    /// from the next request, and it survives `switchCommunity`. A later call replaces the value.
    ///
    /// Hidden behind SPI: it is **not** part of the supported public API. Only the Octopus wrapper SDKs opt
    /// in with `@_spi(OctopusWrapper) import Octopus`.
    ///
    /// - Parameters:
    ///   - family: the wrapper family.
    ///   - version: the wrapper's own version (e.g. the Flutter package version), not the native one.
    @_spi(OctopusWrapper)
    public static func setSdkFamily(_ family: OctopusSDKFamily, version: String) {
        SdkIdentityRegistry.shared.set(wrapper: family.coreValue, version: version)
    }
}
