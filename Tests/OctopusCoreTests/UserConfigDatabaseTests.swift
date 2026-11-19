//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import CoreData
import OctopusDependencyInjection
import OctopusGrpcModels
@testable import OctopusCore

/// The reason of a denied access is stored with it, so that the right screen shows at the next launch before any
/// answer of the server.
struct UserConfigDatabaseTests {
    private let injector: Injector
    private let database: UserConfigDatabase

    init() {
        injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { UserConfigDatabase(injector: $0) }
        database = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
    }

    @Test(arguments: [CommunityNoAccessReason.cohort, .temporarilyDisabled, .closed, .memberExcluded,
                      .accountDeleted, .unknown])
    func aReasonSurvivesTheRoundTrip(reason: CommunityNoAccessReason) async throws {
        try await database.upsert(
            UserConfig(canAccessCommunity: false, accessDeniedMessage: "Msg", noAccessReason: reason))

        #expect(try await storedUserConfig()
                == UserConfig(canAccessCommunity: false, accessDeniedMessage: "Msg", noAccessReason: reason))
    }

    @Test func aBanSurvivesTheRoundTripWithItsDetails() async throws {
        let ban = CommunityNoAccessReason.accountBanned(.init(
            nickname: "marie_l92", policyName: "Job applications", policyDescription: "L1\nL2",
            contactEmail: "a@b.co"))

        try await database.upsert(
            UserConfig(canAccessCommunity: false, accessDeniedMessage: nil, noAccessReason: ban))

        #expect(try await storedUserConfig()?.noAccessReason == ban)
    }

    @Test func aBanWithoutNicknameOrEmailSurvivesTheRoundTrip() async throws {
        let ban = CommunityNoAccessReason.accountBanned(.init(
            nickname: nil, policyName: "Job applications", policyDescription: "", contactEmail: nil))

        try await database.upsert(
            UserConfig(canAccessCommunity: false, accessDeniedMessage: nil, noAccessReason: ban))

        #expect(try await storedUserConfig()?.noAccessReason == ban)
    }

    @Test func aGrantedAccessClearsTheStoredReasonAndBanDetails() async throws {
        try await database.upsert(UserConfig(
            canAccessCommunity: false, accessDeniedMessage: "Banned",
            noAccessReason: .accountBanned(.init(nickname: "n", policyName: "p", policyDescription: "d",
                                                 contactEmail: "a@b.co"))))

        try await database.upsert(UserConfig(canAccessCommunity: true, accessDeniedMessage: nil))

        #expect(try await storedUserConfig() == UserConfig(canAccessCommunity: true, accessDeniedMessage: nil))
        let stored = try await storedAttributes()
        #expect(stored == [nil, nil, nil, nil, nil])
    }

    /// A row written by a server that gives no reason, or by a version of the SDK that stored none.
    @Test func aRowStoredWithoutReasonReadsAsUnknownAndKeepsItsMessage() async throws {
        try await database.upsert(canAccessCommunity: false, message: "Old msg")
        try await setStoredReason(nil)

        let config = try await storedUserConfig()
        #expect(config?.noAccessReason == .unknown)
        #expect(config?.accessDeniedMessage == "Old msg")
    }

    @Test func anUnknownStoredReasonReadsAsUnknown() async throws {
        try await database.upsert(canAccessCommunity: false, message: nil)
        try await setStoredReason("futureCase")

        #expect(try await storedUserConfig()?.noAccessReason == .unknown)
    }

    private var context: NSManagedObjectContext {
        injector.getInjected(identifiedBy: Injected.configCoreDataStack).saveContext
    }

    /// A read that says the session is over is no access to show: the stored one is kept until the session that
    /// replaces it reads its own, and the session the read was sent with is published, to be replaced.
    @Test func anEndedSessionIsPublishedAndNotStored() async throws {
        let ban = UserConfig(canAccessCommunity: false, accessDeniedMessage: "Banned",
                             noAccessReason: .accountBanned(.init(nickname: nil, policyName: "Job applications",
                                                                  policyDescription: "", contactEmail: nil)))
        try await database.upsert(ban)
        let published = Locked<[UserDataStorage.UserData?]>([])
        let cancellable = database.endedSessionPublisher.sink { session in published.mutate { $0.append(session) } }
        let session = UserDataStorage.UserData(id: "guestId", jwtToken: "guestJwt")

        let stored = try await database.store(accessRead: .with {
            $0.canAccessCommunity = false
            $0.communityDisabledMessage = "Check back shortly"
            $0.sessionEnded = .init()
        }, session: session)

        #expect(stored == nil)
        #expect(published.value == [session])
        #expect(try await storedUserConfig() == ban)
        cancellable.cancel()
    }

    @Test func anotherReadIsStoredAndNotPublished() async throws {
        let published = Locked<[UserDataStorage.UserData?]>([])
        let cancellable = database.endedSessionPublisher.sink { session in published.mutate { $0.append(session) } }

        let stored = try await database.store(accessRead: .with {
            $0.canAccessCommunity = false
            $0.memberExcluded = .init()
        }, session: UserDataStorage.UserData(id: "userId", jwtToken: "jwt"))

        let expected = UserConfig(canAccessCommunity: false, accessDeniedMessage: nil, noAccessReason: .memberExcluded)
        #expect(stored == expected)
        #expect(try await storedUserConfig() == expected)
        #expect(published.value.isEmpty)
        cancellable.cancel()
    }

    private func storedUserConfig() async throws -> UserConfig? {
        let context = context
        return try await context.performAsync {
            try context.fetch(UserConfigEntity.fetch()).first.flatMap(UserConfig.init(from:))
        }
    }

    /// The reason and the four ban attributes of the stored row.
    private func storedAttributes() async throws -> [String?] {
        let context = context
        return try await context.performAsync {
            guard let entity = try context.fetch(UserConfigEntity.fetch()).first else { return [] }
            return [entity.noAccessReason, entity.banNickname, entity.banPolicyName, entity.banPolicyDescription,
                    entity.banContactEmail]
        }
    }

    private func setStoredReason(_ reason: String?) async throws {
        let context = context
        try await context.performAsync {
            try context.fetch(UserConfigEntity.fetch()).first?.noAccessReason = reason
            try context.save()
        }
    }
}
