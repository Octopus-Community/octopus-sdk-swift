//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

/// The SDK the host app integrates, as reported to the backend in the `sdkfamily` and `sdkfamilyversion`
/// headers.
///
/// A host app built on a wrapper (Flutter, React Native, Unity) embeds this native SDK, so `sdkVersion`
/// alone cannot tell it apart from a native integration. `sdkVersion` stays the native version because
/// the backend gates features on it; this pair carries the wrapper's own family and version.
public struct SdkIdentity: Sendable, Equatable {
    /// SDK family. The raw values are what the backend receives in the `sdkfamily` header.
    public enum Family: String, Sendable, CaseIterable {
        case native = "Native"
        case flutter = "Flutter"
        case reactNative = "ReactNative"
        case unity = "Unity"
    }

    /// Family of the SDK the host app integrates.
    public let family: Family
    /// Version of the SDK the host app integrates: the wrapper's version for a wrapper.
    public let version: String

    public init(family: Family, version: String) {
        self.family = family
        self.version = version
    }
}
