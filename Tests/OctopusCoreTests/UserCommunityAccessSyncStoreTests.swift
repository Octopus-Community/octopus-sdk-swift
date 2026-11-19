//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

/// The access is read synchronously when the SDK is initialized, before the database answers: the reason of a
/// refusal has to be there too, or the host app and the screen would be told a wrong one for an instant.
struct UserCommunityAccessSyncStoreTests {
    private let userDefaults = UserDefaults(suiteName: "UserCommunityAccessSyncStoreTests-\(UUID())")!

    @Test func nothingStoredGivesNoAccessState() {
        #expect(UserCommunityAccessSyncStore(userDefaults: userDefaults).userConfig == nil)
    }

    @Test(arguments: [CommunityNoAccessReason.cohort, .temporarilyDisabled, .closed, .memberExcluded,
                      .accountDeleted, .unknown])
    func aReasonIsReadBackAtTheNextLaunch(reason: CommunityNoAccessReason) {
        UserCommunityAccessSyncStore(userDefaults: userDefaults).set(
            UserConfig(canAccessCommunity: false, accessDeniedMessage: "Msg", noAccessReason: reason))

        let userConfig = UserCommunityAccessSyncStore(userDefaults: userDefaults).userConfig
        #expect(userConfig?.canAccessCommunity == false)
        #expect(userConfig?.noAccessReason == reason)
    }

    /// Only the kind of the reason is kept here: what the server says about the ban stays in the database.
    @Test func aBanIsReadBackWithoutItsDetails() {
        UserCommunityAccessSyncStore(userDefaults: userDefaults).set(UserConfig(
            canAccessCommunity: false, accessDeniedMessage: "Banned",
            noAccessReason: .accountBanned(.init(nickname: "marie_l92", policyName: "Job applications",
                                                 policyDescription: "Desc", contactEmail: "a@b.co"))))

        let userConfig = UserCommunityAccessSyncStore(userDefaults: userDefaults).userConfig
        #expect(userConfig?.noAccessReason == .accountBanned(nil))
        #expect(userConfig?.accessDeniedMessage == nil)
        // No sentence can be written about a ban whose details are not read yet
        #expect(userConfig?.banMessage == nil)
    }

    @Test func aGrantedAccessForgetsTheReason() {
        let store = UserCommunityAccessSyncStore(userDefaults: userDefaults)
        store.set(UserConfig(canAccessCommunity: false, accessDeniedMessage: nil, noAccessReason: .closed))
        store.set(UserConfig(canAccessCommunity: true, accessDeniedMessage: nil))

        let userConfig = UserCommunityAccessSyncStore(userDefaults: userDefaults).userConfig
        #expect(userConfig == UserConfig(canAccessCommunity: true, accessDeniedMessage: nil))
        #expect(userDefaults.object(forKey: "OctopusSDK.UserConfig.noAccessReason") == nil)
    }

    /// What a previous version of the SDK left: the access without its reason.
    @Test func anAccessStoredWithoutReasonIsUnknown() {
        userDefaults.set(false, forKey: "OctopusSDK.UserConfig.hasAccessToCommunityKey")

        #expect(UserCommunityAccessSyncStore(userDefaults: userDefaults).userConfig?.noAccessReason == .unknown)
    }

    @Test func clearingForgetsTheAccessAndItsReason() {
        let store = UserCommunityAccessSyncStore(userDefaults: userDefaults)
        store.set(UserConfig(canAccessCommunity: false, accessDeniedMessage: nil, noAccessReason: .closed))

        store.clear()

        #expect(UserCommunityAccessSyncStore(userDefaults: userDefaults).userConfig == nil)
    }
}
