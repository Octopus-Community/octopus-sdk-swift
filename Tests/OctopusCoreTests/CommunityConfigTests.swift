//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import Combine
import OctopusGrpcModels
import OctopusDependencyInjection
@testable import OctopusCore

/// Mapping of the gRPC `ApiKeyConfig` onto the `CommunityConfig` domain model,
/// focusing on the per-field profile lock.
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
                                     termsAcceptanceMode: .implicit,
                                     showCommentsOnOtherProfiles: false, forceNicknameChoice: false, consentTexts: nil)
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertEqual(stored.profileFieldsLock, lock)
    }

    func testWithProfileFieldsLockReplacesOnlyTheLock() {
        let base = CommunityConfig(forceLoginOnStrongActions: true, displayAccountAge: true,
                                   gamificationConfig: nil, displayConfig: nil, profileFieldsLock: .allEditable,
                                   contentOptions: .allEnabled, exposeClientUserId: false,
                                   termsAcceptanceMode: .implicit,
                                   showCommentsOnOtherProfiles: false, forceNicknameChoice: false, consentTexts: nil)
        let clue = ProfileFieldsLock(nickname: .readOnly, avatar: .readOnly, bio: .disabled)

        let overridden = base.withProfileFieldsLock(clue)

        XCTAssertEqual(overridden.profileFieldsLock, clue)
        // every other field is preserved
        XCTAssertEqual(overridden.forceLoginOnStrongActions, base.forceLoginOnStrongActions)
        XCTAssertEqual(overridden.displayAccountAge, base.displayAccountAge)
        XCTAssertEqual(overridden.gamificationConfig, base.gamificationConfig)
        XCTAssertEqual(overridden.displayConfig, base.displayConfig)
    }

    // MARK: exposeClientUserId (Unified Profile activation flag)

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
                                     exposeClientUserId: true, termsAcceptanceMode: .implicit,
                                     showCommentsOnOtherProfiles: false, forceNicknameChoice: false, consentTexts: nil)
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertTrue(stored.exposeClientUserId)
    }

    func testWithExposeClientUserIdReplacesOnlyTheFlag() {
        let base = CommunityConfig(forceLoginOnStrongActions: true, displayAccountAge: true,
                                   gamificationConfig: nil, displayConfig: nil, profileFieldsLock: .allEditable,
                                   contentOptions: .allEnabled, exposeClientUserId: false,
                                   termsAcceptanceMode: .implicit,
                                   showCommentsOnOtherProfiles: false, forceNicknameChoice: false, consentTexts: nil)

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
            contentOptions: .allEnabled, exposeClientUserId: true, termsAcceptanceMode: .implicit,
            showCommentsOnOtherProfiles: false, forceNicknameChoice: false, consentTexts: nil))
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

    // MARK: termsAcceptanceMode (explicit terms acceptance)

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
                                     exposeClientUserId: false, termsAcceptanceMode: .explicitSingleCheckbox,
                                     showCommentsOnOtherProfiles: false, forceNicknameChoice: false, consentTexts: nil)
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertEqual(stored.termsAcceptanceMode, .explicitSingleCheckbox)
    }

    // MARK: showCommentsOnOtherProfiles (profile Comments tab on other profiles)

    func testShowCommentsOnOtherProfilesMappedFromProto() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.showCommentsOnOtherProfiles = true
        }

        XCTAssertTrue(CommunityConfig(from: config).showCommentsOnOtherProfiles)
    }

    func testShowCommentsOnOtherProfilesAbsentDefaultsToFalse() {
        // Plain proto3 bool: false when unset (no has-guard). Comments tab stays own-profile-only.
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.displayAccountAge = true
        }

        XCTAssertFalse(CommunityConfig(from: config).showCommentsOnOtherProfiles)
    }

    func testShowCommentsOnOtherProfilesPersistsThroughDatabase() async throws {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        let db = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)

        let config = CommunityConfig(forceLoginOnStrongActions: false, displayAccountAge: false,
                                     gamificationConfig: nil, displayConfig: nil,
                                     profileFieldsLock: .allEditable, contentOptions: .allEnabled,
                                     exposeClientUserId: false, termsAcceptanceMode: .implicit,
                                     showCommentsOnOtherProfiles: true, forceNicknameChoice: false, consentTexts: nil)
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertTrue(stored.showCommentsOnOtherProfiles)
    }

    func testWithShowCommentsOnOtherProfilesReplacesOnlyTheFlag() {
        let base = CommunityConfig(forceLoginOnStrongActions: true, displayAccountAge: true,
                                   gamificationConfig: nil, displayConfig: nil, profileFieldsLock: .allEditable,
                                   contentOptions: .allEnabled, exposeClientUserId: true,
                                   termsAcceptanceMode: .explicitSingleCheckbox,
                                   showCommentsOnOtherProfiles: false, forceNicknameChoice: false, consentTexts: nil)

        let overridden = base.withShowCommentsOnOtherProfiles(true)

        XCTAssertTrue(overridden.showCommentsOnOtherProfiles)
        // every other field is preserved
        XCTAssertEqual(overridden.forceLoginOnStrongActions, base.forceLoginOnStrongActions)
        XCTAssertEqual(overridden.exposeClientUserId, base.exposeClientUserId)
        XCTAssertEqual(overridden.termsAcceptanceMode, base.termsAcceptanceMode)
        XCTAssertEqual(overridden.profileFieldsLock, base.profileFieldsLock)
        XCTAssertEqual(overridden.contentOptions, base.contentOptions)
    }

    // MARK: consentTexts (community consent wordings)

    func testConsentTextsPersistThroughDatabase() async throws {
        let cases: [ConsentTexts?] = [
            nil,
            .implicit(notice: "Notice with a [link](https://example.com)"),
            .implicit(notice: nil),
            .multiCheckbox(termsLabel: "Terms", privacyLabel: nil, rulesLabel: "Rules"),
            .singleCheckbox(label: nil, belowText: "Below"),
        ]
        for texts in cases {
            let injector = Injector()
            injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
            injector.register { CommunityConfigDatabase(injector: $0) }
            let db = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)

            try await db.upsert(config: CommunityConfig(from: Com_Octopuscommunity_ApiKeyConfig.with { _ in })
                .withConsentTexts(texts))

            let stored = try await firstNonNil(db.configPublisher())
            XCTAssertEqual(stored.consentTexts, texts)
        }
    }

    func testConsentTextsAreReplacedOnUpdate() async throws {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        let db = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)
        var latest: CommunityConfig?
        db.configPublisher().sink { latest = $0 }.store(in: &storage)
        let base = CommunityConfig(from: Com_Octopuscommunity_ApiKeyConfig.with { _ in })

        try await db.upsert(config: base.withConsentTexts(.implicit(notice: "Old notice")))
        try await assertWithTimeout(timeout: 5, latest?.consentTexts == .implicit(notice: "Old notice"))

        // Same row updated: the emptied notice must not survive.
        try await db.upsert(config: base.withConsentTexts(.implicit(notice: nil)))
        try await assertWithTimeout(timeout: 5, latest?.consentTexts == .implicit(notice: nil))

        try await db.upsert(config: base.withConsentTexts(nil))
        try await assertWithTimeout(timeout: 5, latest != nil && latest?.consentTexts == nil)
    }

    func testDebugOverrideConsentTexts() async throws {
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

        // Seed the backend-driven config with implicit texts.
        let backendTexts = ConsentTexts.implicit(notice: "Backend notice")
        try await communityConfigDatabase.upsert(config: CommunityConfig(
            from: Com_Octopuscommunity_ApiKeyConfig.with { _ in }).withConsentTexts(backendTexts))
        try await assertWithTimeout(timeout: 5, published?.consentTexts == backendTexts)

        // Override on top of the backend value.
        let overridden = ConsentTexts.singleCheckbox(label: "Label", belowText: nil)
        repo.debugOverrideConsentTexts(overridden)
        try await assertWithTimeout(timeout: 5, published?.consentTexts == overridden)

        // The mode override applies on top without dropping the texts override.
        repo.debugOverrideTermsAcceptanceMode(.explicitSingleCheckbox)
        try await assertWithTimeout(timeout: 5,
                                    published?.termsAcceptanceMode == .explicitSingleCheckbox
                                    && published?.consentTexts == overridden)

        // A new backend config landing meanwhile does not displace the override.
        let backendTextsV2 = ConsentTexts.implicit(notice: "Backend v2")
        try await communityConfigDatabase.upsert(config: CommunityConfig(
            from: Com_Octopuscommunity_ApiKeyConfig.with { _ in }).withConsentTexts(backendTextsV2))
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(published?.consentTexts, overridden)

        // Clear the override → falls back to the latest backend value.
        repo.debugOverrideConsentTexts(nil)
        try await assertWithTimeout(timeout: 5, published?.consentTexts == backendTextsV2)
    }

    /// Awaits the first non-nil value of a config publisher (the stored config after an upsert).
    /// Combine-based (iOS 13 compatible — `AsyncPublisher.values` needs iOS 15).
    private func firstNonNil(_ publisher: AnyPublisher<CommunityConfig?, Never>) async throws -> CommunityConfig {
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

    // MARK: forceNicknameChoice (nickname typed by the member before the first contribution)

    func testForceNicknameChoiceMappedFromProto() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.forceNicknameChoice = true
        }

        XCTAssertTrue(CommunityConfig(from: config).forceNicknameChoice)
    }

    func testForceNicknameChoiceAbsentDefaultsToFalse() {
        // Plain proto3 bool: false when unset. The nickname choice screen is prefilled.
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.displayAccountAge = true
        }

        XCTAssertFalse(CommunityConfig(from: config).forceNicknameChoice)
    }

    func testForceNicknameChoicePersistsThroughDatabase() async throws {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        let db = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)

        let config = CommunityConfig(forceLoginOnStrongActions: false, displayAccountAge: false,
                                     gamificationConfig: nil, displayConfig: nil,
                                     profileFieldsLock: .allEditable, contentOptions: .allEnabled,
                                     exposeClientUserId: false, termsAcceptanceMode: .implicit,
                                     showCommentsOnOtherProfiles: false, forceNicknameChoice: true, consentTexts: nil)
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertTrue(stored.forceNicknameChoice)
    }

    func testWithForceNicknameChoiceReplacesOnlyTheFlag() {
        let base = CommunityConfig(forceLoginOnStrongActions: true, displayAccountAge: true,
                                   gamificationConfig: nil, displayConfig: nil, profileFieldsLock: .allEditable,
                                   contentOptions: .allEnabled, exposeClientUserId: true,
                                   termsAcceptanceMode: .explicitSingleCheckbox,
                                   showCommentsOnOtherProfiles: true, forceNicknameChoice: false, consentTexts: nil)

        let updated = base.withForceNicknameChoice(true)

        XCTAssertTrue(updated.forceNicknameChoice)
        XCTAssertEqual(updated.withForceNicknameChoice(false), base)
    }

    func testDebugOverrideForceNicknameChoice() async throws {
        let (repo, communityConfigDatabase) = makeConfigRepository()

        var published: CommunityConfig?
        repo.communityConfigPublisher.sink { published = $0 }.store(in: &storage)

        // Seed the backend-driven config with the flag enabled.
        try await communityConfigDatabase.upsert(config: configWith(forceNicknameChoice: true))
        try await assertWithTimeout(timeout: 5, published?.forceNicknameChoice == true)

        // Override OFF on top of the backend value.
        repo.debugOverrideForceNicknameChoice(false)
        try await assertWithTimeout(timeout: 5, published?.forceNicknameChoice == false)

        // Override ON.
        repo.debugOverrideForceNicknameChoice(true)
        try await assertWithTimeout(timeout: 5, published?.forceNicknameChoice == true)

        // Override OFF again, then clear the override: falls back to the backend value (true).
        repo.debugOverrideForceNicknameChoice(false)
        try await assertWithTimeout(timeout: 5, published?.forceNicknameChoice == false)
        repo.debugOverrideForceNicknameChoice(nil)
        try await assertWithTimeout(timeout: 5, published?.forceNicknameChoice == true)
    }

    /// The repository applies each debug override on top of the stored config with its `with…` helper, one after
    /// the other: checked on the value, as the publication itself is covered by the single-override tests above.
    func testForceNicknameChoiceAndTermsAcceptanceOverridesCombine() {
        // Backend: flag off, implicit terms.
        let backend = configWith(forceNicknameChoice: false)

        // Both overrides are applied, whatever their order.
        let both = backend.withTermsAcceptanceMode(.explicitSingleCheckbox).withForceNicknameChoice(true)
        XCTAssertTrue(both.forceNicknameChoice)
        XCTAssertEqual(both.termsAcceptanceMode, .explicitSingleCheckbox)
        XCTAssertEqual(backend.withForceNicknameChoice(true).withTermsAcceptanceMode(.explicitSingleCheckbox), both)

        // Clearing the nickname override leaves the terms one in place.
        let termsOnly = backend.withTermsAcceptanceMode(.explicitSingleCheckbox)
        XCTAssertFalse(termsOnly.forceNicknameChoice)
        XCTAssertEqual(termsOnly.termsAcceptanceMode, .explicitSingleCheckbox)
    }

    private func makeConfigRepository() -> (ConfigRepository, CommunityConfigDatabase) {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .networkMonitor, .appStateMonitor, .authProvider, .securedStorage)
        injector.register { UserDataStorage(injector: $0) }
        let communityConfigDatabase = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)
        return (ConfigRepositoryDefault(injector: injector), communityConfigDatabase)
    }

    private func configWith(forceNicknameChoice: Bool) -> CommunityConfig {
        CommunityConfig(
            forceLoginOnStrongActions: false, displayAccountAge: false,
            gamificationConfig: nil, displayConfig: nil, profileFieldsLock: .allEditable,
            contentOptions: .allEnabled, exposeClientUserId: false, termsAcceptanceMode: .implicit,
            showCommentsOnOtherProfiles: false, forceNicknameChoice: forceNicknameChoice, consentTexts: nil)
    }
}
