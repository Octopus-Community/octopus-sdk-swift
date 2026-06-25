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
                                     contentOptions: .allEnabled)
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertEqual(stored.profileFieldsLock, lock)
    }

    func testWithProfileFieldsLockReplacesOnlyTheLock() {
        let base = CommunityConfig(forceLoginOnStrongActions: true, displayAccountAge: true,
                                   gamificationConfig: nil, displayConfig: nil, profileFieldsLock: .allEditable,
                                   contentOptions: .allEnabled)
        let clue = ProfileFieldsLock(nickname: .readOnly, avatar: .readOnly, bio: .disabled)

        let overridden = base.withProfileFieldsLock(clue)

        XCTAssertEqual(overridden.profileFieldsLock, clue)
        // every other field is preserved
        XCTAssertEqual(overridden.forceLoginOnStrongActions, base.forceLoginOnStrongActions)
        XCTAssertEqual(overridden.displayAccountAge, base.displayAccountAge)
        XCTAssertEqual(overridden.gamificationConfig, base.gamificationConfig)
        XCTAssertEqual(overridden.displayConfig, base.displayConfig)
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
