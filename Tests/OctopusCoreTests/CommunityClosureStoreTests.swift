//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

/// The closure is read synchronously when the SDK starts, before any call, and belongs to one API key: switching to
/// another community must not inherit it, and coming back must find it.
struct CommunityClosureStoreTests {
    private let userDefaults = UserDefaults(suiteName: "CommunityClosureStoreTests-\(UUID())")!
    private let closure = CommunityClosure(kind: .closed, message: "Closed msg",
                                           nextCheckDate: Date(timeIntervalSince1970: 1_800_000_000))

    @Test func aStoredClosureIsReadBackByANewStore() {
        CommunityClosureStore(apiKey: "keyA", userDefaults: userDefaults).set(closure)

        #expect(CommunityClosureStore(apiKey: "keyA", userDefaults: userDefaults).closure == closure)
    }

    @Test func eachApiKeyHasItsOwnClosure() {
        CommunityClosureStore(apiKey: "keyA", userDefaults: userDefaults).set(closure)

        #expect(CommunityClosureStore(apiKey: "keyB", userDefaults: userDefaults).closure == nil)
        #expect(CommunityClosureStore(apiKey: "keyA", userDefaults: userDefaults).closure == closure)
    }

    /// The user defaults are shared with the host app and its other SDKs, and saved with the device backups.
    @Test func theApiKeyIsNotWrittenInTheUserDefaults() {
        CommunityClosureStore(apiKey: "secretApiKey", userDefaults: userDefaults).set(closure)

        let keys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("OctopusSDK.CommunityClosure.") }
        #expect(keys.count == 1)
        #expect(keys.allSatisfy { !$0.contains("secretApiKey") })
    }

    @Test func settingNilForgetsTheClosure() {
        let store = CommunityClosureStore(apiKey: "keyA", userDefaults: userDefaults)
        store.set(closure)

        store.set(nil)

        #expect(store.closure == nil)
        #expect(CommunityClosureStore(apiKey: "keyA", userDefaults: userDefaults).closure == nil)
    }

    /// The purge is asked before the closure is published, and survives a kill until it is done.
    @Test func aPendingPurgeIsReadBackByANewStore() {
        let store = CommunityClosureStore(apiKey: "keyA", userDefaults: userDefaults)
        #expect(!store.isPurgePending)

        store.set(purgePending: true)

        #expect(CommunityClosureStore(apiKey: "keyA", userDefaults: userDefaults).isPurgePending)
        #expect(!CommunityClosureStore(apiKey: "keyB", userDefaults: userDefaults).isPurgePending)
        store.set(purgePending: false)
        #expect(!CommunityClosureStore(apiKey: "keyA", userDefaults: userDefaults).isPurgePending)
    }
}
