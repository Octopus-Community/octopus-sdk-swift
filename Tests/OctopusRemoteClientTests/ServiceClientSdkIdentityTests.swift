//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
@testable import OctopusRemoteClient

/// The SDK family and the version of the SDK the client integrates travel in two headers of their own,
/// next to `sdkVersion`, which stays the native version because the backend gates features on it.
@Suite("ServiceClient SDK identity headers")
struct ServiceClientSdkIdentityTests {

    /// Lets a test change the identity between two calls from a `@Sendable` closure.
    /// Accessed sequentially within one test, hence no lock.
    private final class IdentityBox: @unchecked Sendable {
        var value: SdkIdentity
        init(_ value: SdkIdentity) { self.value = value }
    }

    private func makeClient(identity: @escaping @Sendable () -> SdkIdentity) -> ServiceClient {
        ServiceClient(apiKey: "api-key", sdkVersion: "1.15.0", installId: "install-id",
                      localeIdentifier: "fr_FR", sdkIdentity: identity)
    }

    @Test func nativeIdentityIsSentWithTheNativeVersion() {
        let client = makeClient { SdkIdentity(family: .native, version: "1.15.0") }

        let metadata = client.getCallOptions(authenticationMethod: .notAuthenticated).customMetadata

        #expect(metadata.first(name: "sdkfamily") == "Native")
        #expect(metadata.first(name: "sdkfamilyversion") == "1.15.0")
        #expect(metadata.first(name: "sdkVersion") == "1.15.0")
    }

    @Test func wrapperIdentityDoesNotTouchTheNativeVersion() {
        let client = makeClient { SdkIdentity(family: .flutter, version: "1.14.0") }

        let metadata = client.getCallOptions(authenticationMethod: .notAuthenticated).customMetadata

        #expect(metadata.first(name: "sdkfamily") == "Flutter")
        #expect(metadata.first(name: "sdkfamilyversion") == "1.14.0")
        #expect(metadata.first(name: "sdkVersion") == "1.15.0")
    }

    /// A wrapper that declares itself after the SDK is created must still be reported from the next call.
    @Test func identityIsReadAgainOnEachCall() {
        let box = IdentityBox(SdkIdentity(family: .native, version: "1.15.0"))
        let client = makeClient { box.value }

        let first = client.getCallOptions(authenticationMethod: .notAuthenticated).customMetadata
        #expect(first.first(name: "sdkfamily") == "Native")
        box.value = SdkIdentity(family: .unity, version: "1.14.1")
        let metadata = client.getCallOptions(authenticationMethod: .notAuthenticated).customMetadata

        #expect(metadata.first(name: "sdkfamily") == "Unity")
        #expect(metadata.first(name: "sdkfamilyversion") == "1.14.1")
    }

    /// The raw values are the wire contract with the backend: changing one breaks the dashboard.
    @Test func familyRawValuesAreTheWireContract() {
        #expect(SdkIdentity.Family.allCases.map(\.rawValue) == ["Native", "Flutter", "ReactNative", "Unity"])
    }
}
