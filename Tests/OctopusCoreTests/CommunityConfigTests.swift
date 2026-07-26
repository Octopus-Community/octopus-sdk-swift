//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import Combine
import OctopusGrpcModels
import OctopusDependencyInjection
@testable import OctopusCore

/// Mapping of the gRPC `ApiKeyConfig` onto the `CommunityConfig` domain model,
/// focusing on the per-field profile lock (OCT-1487).
final class CommunityConfigTests: XCTestCase {

    private var storage = [AnyCancellable]()

    func testProfileFieldsLockMappedFromProto() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.profileFieldsLock = .with {
                $0.nickname = .readOnly
                $0.avatar = .editable
                $0.bio = .hidden
            }
        }

        let community = CommunityConfig(from: config)

        XCTAssertEqual(community.profileFieldsLock.nickname, .readOnly)
        XCTAssertEqual(community.profileFieldsLock.avatar, .editable)
        XCTAssertEqual(community.profileFieldsLock.bio, .disabled)
    }

    func testProfileFieldsLockAbsentDefaultsToAllEditable() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.displayAccountAge = true
        }

        let community = CommunityConfig(from: config)

        XCTAssertEqual(community.profileFieldsLock, .allEditable)
        XCTAssertEqual(community.profileFieldsLock.nickname, .editable)
        XCTAssertEqual(community.profileFieldsLock.avatar, .editable)
        XCTAssertEqual(community.profileFieldsLock.bio, .editable)
    }

    func testProfileFieldsLockUnknownValueDefaultsToEditable() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.profileFieldsLock = .with {
                $0.nickname = .UNRECOGNIZED(99)
                $0.bio = .UNRECOGNIZED(99)
            }
        }

        let community = CommunityConfig(from: config)

        XCTAssertEqual(community.profileFieldsLock.nickname, .editable)
        XCTAssertEqual(community.profileFieldsLock.bio, .editable)
    }

    func testProfileFieldsLockPersistsThroughDatabase() async throws {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        let db = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)

        let lock = ProfileFieldsLock(nickname: .readOnly, avatar: .editable, bio: .disabled)
        let config = CommunityConfig(forceLoginOnStrongActions: false, displayAccountAge: false,
                                     gamificationConfig: nil, displayConfig: nil, profileFieldsLock: lock,
                                     contentOptions: .allEnabled, exposeClientUserId: false,
                                     termsAcceptanceMode: .implicit)
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertEqual(stored.profileFieldsLock, lock)
    }

    func testWithProfileFieldsLockReplacesOnlyTheLock() {
        let base = CommunityConfig(forceLoginOnStrongActions: true, displayAccountAge: true,
                                   gamificationConfig: nil, displayConfig: nil, profileFieldsLock: .allEditable,
                                   contentOptions: .allEnabled, exposeClientUserId: false,
                                   termsAcceptanceMode: .implicit)
        let clue = ProfileFieldsLock(nickname: .readOnly, avatar: .readOnly, bio: .disabled)

        let overridden = base.withProfileFieldsLock(clue)

        XCTAssertEqual(overridden.profileFieldsLock, clue)
        // every other field is preserved
        XCTAssertEqual(overridden.forceLoginOnStrongActions, base.forceLoginOnStrongActions)
        XCTAssertEqual(overridden.displayAccountAge, base.displayAccountAge)
        XCTAssertEqual(overridden.gamificationConfig, base.gamificationConfig)
        XCTAssertEqual(overridden.displayConfig, base.displayConfig)
    }

    // MARK: exposeClientUserId (Unified Profile activation flag, OCT-1374)

    func testExposeClientUserIdMappedFromProto() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.exposeClientUserID = true
        }

        XCTAssertTrue(CommunityConfig(from: config).exposeClientUserId)
    }

    func testExposeClientUserIdAbsentDefaultsToFalse() {
        // Plain proto3 bool: false when unset (no has-guard).
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.displayAccountAge = true
        }

        XCTAssertFalse(CommunityConfig(from: config).exposeClientUserId)
    }

    func testExposeClientUserIdPersistsThroughDatabase() async throws {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        let db = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)

        let config = CommunityConfig(forceLoginOnStrongActions: false, displayAccountAge: false,
                                     gamificationConfig: nil, displayConfig: nil,
                                     profileFieldsLock: .allEditable, contentOptions: .allEnabled,
                                     exposeClientUserId: true, termsAcceptanceMode: .implicit)
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertTrue(stored.exposeClientUserId)
    }

    func testWithExposeClientUserIdReplacesOnlyTheFlag() {
        let base = CommunityConfig(forceLoginOnStrongActions: true, displayAccountAge: true,
                                   gamificationConfig: nil, displayConfig: nil, profileFieldsLock: .allEditable,
                                   contentOptions: .allEnabled, exposeClientUserId: false,
                                   termsAcceptanceMode: .implicit)

        let overridden = base.withExposeClientUserId(true)

        XCTAssertTrue(overridden.exposeClientUserId)
        // every other field is preserved
        XCTAssertEqual(overridden.forceLoginOnStrongActions, base.forceLoginOnStrongActions)
        XCTAssertEqual(overridden.displayAccountAge, base.displayAccountAge)
        XCTAssertEqual(overridden.profileFieldsLock, base.profileFieldsLock)
        XCTAssertEqual(overridden.contentOptions, base.contentOptions)
    }

    func testDebugOverrideExposeClientUserId() async throws {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .networkMonitor, .appStateMonitor, .authProvider, .securedStorage)
        injector.register { UserDataStorage(injector: $0) }
        let communityConfigDatabase = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)

        let repo: ConfigRepository = ConfigRepositoryDefault(injector: injector)

        var published: CommunityConfig?
        repo.communityConfigPublisher.sink { published = $0 }.store(in: &storage)

        // Seed the backend-driven config with the flag enabled.
        try await communityConfigDatabase.upsert(config: CommunityConfig(
            forceLoginOnStrongActions: false, displayAccountAge: false,
            gamificationConfig: nil, displayConfig: nil, profileFieldsLock: .allEditable,
            contentOptions: .allEnabled, exposeClientUserId: true, termsAcceptanceMode: .implicit))
        try await assertWithTimeout(timeout: 5, published?.exposeClientUserId == true)

        // Override OFF on top of the backend value.
        repo.debugOverrideExposeClientUserId(false)
        try await assertWithTimeout(timeout: 5, published?.exposeClientUserId == false)

        // Override ON.
        repo.debugOverrideExposeClientUserId(true)
        try await assertWithTimeout(timeout: 5, published?.exposeClientUserId == true)

        // Clear the override → falls back to the backend value (true).
        repo.debugOverrideExposeClientUserId(nil)
        try await assertWithTimeout(timeout: 5, published?.exposeClientUserId == true)
    }

    // MARK: termsAcceptanceMode (explicit terms acceptance, OCT-1633)

    func testTermsAcceptanceModeMappedFromProto() {
        let multi = Com_Octopuscommunity_ApiKeyConfig.with { $0.termsAcceptanceMode = .explicitMultiCheckbox }
        let single = Com_Octopuscommunity_ApiKeyConfig.with { $0.termsAcceptanceMode = .explicitSingleCheckbox }

        XCTAssertEqual(CommunityConfig(from: multi).termsAcceptanceMode, .explicitMultiCheckbox)
        XCTAssertEqual(CommunityConfig(from: single).termsAcceptanceMode, .explicitSingleCheckbox)
    }

    func testTermsAcceptanceModeAbsentDefaultsToImplicit() {
        // Plain proto3 enum: .implicit (0) when unset.
        let config = Com_Octopuscommunity_ApiKeyConfig.with { $0.displayAccountAge = true }

        XCTAssertEqual(CommunityConfig(from: config).termsAcceptanceMode, .implicit)
        XCTAssertFalse(CommunityConfig(from: config).termsAcceptanceMode.isExplicit)
    }

    func testTermsAcceptanceModeUnknownValueDefaultsToImplicit() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with { $0.termsAcceptanceMode = .UNRECOGNIZED(99) }

        XCTAssertEqual(CommunityConfig(from: config).termsAcceptanceMode, .implicit)
    }

    func testTermsAcceptanceModePersistsThroughDatabase() async throws {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        let db = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)

        let config = CommunityConfig(forceLoginOnStrongActions: false, displayAccountAge: false,
                                     gamificationConfig: nil, displayConfig: nil,
                                     profileFieldsLock: .allEditable, contentOptions: .allEnabled,
                                     exposeClientUserId: false, termsAcceptanceMode: .explicitSingleCheckbox)
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertEqual(stored.termsAcceptanceMode, .explicitSingleCheckbox)
    }

    /// Awaits the first non-nil value of a config publisher (the stored config after an upsert).
    /// Combine-based (iOS 13 compatible — `AsyncPublisher.values` needs iOS 15).
    private func firstNonNil(_ publisher: AnyPublisher<CommunityConfig?, Error>) async throws -> CommunityConfig {
        var cancellable: AnyCancellable?
        var resumed = false
        return try await withCheckedThrowingContinuation { continuation in
            cancellable = publisher
                .compactMap { $0 }
                .first()
                .sink(
                    receiveCompletion: { completion in
                        if case let .failure(error) = completion, !resumed {
                            resumed = true
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        guard !resumed else { return }
                        resumed = true
                        continuation.resume(returning: value)
                    }
                )
        }
    }
}
