//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Whether the host app draws with the glass effect (Liquid Glass). Every element the SDK draws in glass reads
/// ``isAvailable`` instead of checking the OS version, so an app without the glass effect gets the pre-glass
/// rendering everywhere rather than a mix of both designs.
enum GlassEffect {
    /// The decision for this process. The OS settles it at launch, so it is computed once.
    ///
    /// Three facts make it:
    /// - the app is built with Xcode 26 or later. The SDK is always compiled from source with the app (SPM,
    ///   CocoaPods), so the compiler version is the app's: an app built with an older Xcode runs without the glass
    ///   effect, and the glass APIs are not even compiled.
    /// - the device runs iOS 26 or later.
    /// - the app has not opted out with `UIDesignRequiresCompatibility` in its Info.plist. iOS only honors a
    ///   boolean `true`, and stops honoring the key for an app built with Xcode 27 (iOS 27 SDK) running on iOS 27:
    ///   that app gets the glass effect whatever the key says. Built with Xcode 26, or running on iOS 26, the key
    ///   still applies (checked on the iOS 26.5 and 27.1 simulators).
    static let isAvailable: Bool = {
        var osSupportsGlass = false
        var osHonorsCompatibilityKey = true
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            osSupportsGlass = true
        }
#endif
#if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            osHonorsCompatibilityKey = false
        }
#endif
        return isAvailable(
            osSupportsGlass: osSupportsGlass,
            osHonorsCompatibilityKey: osHonorsCompatibilityKey,
            designRequiresCompatibility: Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility"))
    }()

    /// - Parameters:
    ///   - osSupportsGlass: the app is built with Xcode 26 or later and runs on iOS 26 or later.
    ///   - osHonorsCompatibilityKey: iOS still applies `UIDesignRequiresCompatibility` to this app.
    ///   - designRequiresCompatibility: the value of `UIDesignRequiresCompatibility` in the app's Info.plist.
    static func isAvailable(osSupportsGlass: Bool, osHonorsCompatibilityKey: Bool,
                            designRequiresCompatibility: Any?) -> Bool {
        guard osSupportsGlass else { return false }
        guard osHonorsCompatibilityKey else { return true }
        // A string, even "YES", is not honored by iOS: only a boolean opts the app out.
        let optedOut = designRequiresCompatibility as? Bool ?? false
        return !optedOut
    }
}
