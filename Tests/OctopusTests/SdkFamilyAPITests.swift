//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@_spi(OctopusWrapper) @testable import Octopus
@testable import OctopusCore
import OctopusRemoteClient

/// The wrapper SDKs (Flutter, React Native, Unity) call this hidden API before creating `OctopusSDK`.
/// The end-to-end test writes the process-wide registry and restores it; no other test reads it.
@Suite("OctopusSDK.setSdkFamily")
struct SdkFamilyAPITests {

    @Test(arguments: [
        (OctopusSDKFamily.flutter, SdkWrapper.flutter),
        (OctopusSDKFamily.reactNative, SdkWrapper.reactNative),
        (OctopusSDKFamily.unity, SdkWrapper.unity),
    ])
    func eachFamilyMapsToItsCoreWrapper(family: OctopusSDKFamily, expected: SdkWrapper) {
        #expect(family.coreValue == expected)
    }

    /// A family added to `OctopusSDKFamily` without a test case above would go unchecked.
    @Test func everyFamilyIsCovered() {
        #expect(OctopusSDKFamily.allCases == [.flutter, .reactNative, .unity])
    }

    @Test func setSdkFamilyReachesTheRegistry() {
        defer { SdkIdentityRegistry.shared.set(family: .native, version: OctopusCore.version) }

        OctopusSDK.setSdkFamily(.reactNative, version: "9.8.7")

        #expect(SdkIdentityRegistry.shared.current == SdkIdentity(family: .reactNative, version: "9.8.7"))
    }
}
