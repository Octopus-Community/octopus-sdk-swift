//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusRemoteClient
@testable import OctopusCore

@Suite("SdkIdentityRegistry")
struct SdkIdentityRegistryTests {

    @Test func defaultsToNativeWithTheNativeVersion() {
        let registry = SdkIdentityRegistry()

        #expect(registry.current == SdkIdentity(family: .native, version: version))
    }

    @Test func setReplacesTheIdentity() {
        let registry = SdkIdentityRegistry()

        registry.set(family: .reactNative, version: "1.13.3")

        #expect(registry.current == SdkIdentity(family: .reactNative, version: "1.13.3"))
    }

    @Test func lastSetWins() {
        let registry = SdkIdentityRegistry()

        registry.set(family: .flutter, version: "1.14.0")
        registry.set(family: .unity, version: "1.14.1")

        #expect(registry.current == SdkIdentity(family: .unity, version: "1.14.1"))
    }

    @Test(arguments: [
        (SdkWrapper.flutter, SdkIdentity.Family.flutter),
        (SdkWrapper.reactNative, SdkIdentity.Family.reactNative),
        (SdkWrapper.unity, SdkIdentity.Family.unity),
    ])
    func setWrapperRecordsItsFamily(wrapper: SdkWrapper, expected: SdkIdentity.Family) {
        let registry = SdkIdentityRegistry()

        registry.set(wrapper: wrapper, version: "9.8.7")

        #expect(registry.current == SdkIdentity(family: expected, version: "9.8.7"))
    }

    /// A wrapper added to `SdkWrapper` without a test case above would go unchecked.
    @Test func everyWrapperIsCovered() {
        #expect(SdkWrapper.allCases == [.flutter, .reactNative, .unity])
    }
}
