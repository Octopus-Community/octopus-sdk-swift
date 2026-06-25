//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import Combine
import OctopusGrpcModels
import OctopusDependencyInjection
@testable import OctopusCore

/// Mapping of the gRPC `ContentOptions` onto the `CommunityConfig` domain model (OCT-1426).
/// Highest-priority invariant: absence ⇒ everything enabled (no behaviour change).
final class ContentOptionsTests: XCTestCase {

    func testContentOptionsMappedFromProto() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.contentOptions = .with {
                $0.post = .with { $0.enablePictures = false; $0.enablePolls = false }
                $0.comment = .with { $0.enablePictures = false }
                $0.reply = .with { $0.enablePictures = true }
            }
        }

        let community = CommunityConfig(from: config)

        XCTAssertFalse(community.contentOptions.post.enablePictures)
        XCTAssertFalse(community.contentOptions.post.enablePolls)
        XCTAssertFalse(community.contentOptions.comment.enablePictures)
        XCTAssertTrue(community.contentOptions.reply.enablePictures)
    }

    func testContentOptionsAbsentDefaultsToEverythingEnabled() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.displayAccountAge = true
        }

        let community = CommunityConfig(from: config)

        XCTAssertEqual(community.contentOptions, .allEnabled)
        XCTAssertTrue(community.contentOptions.post.enablePictures)
        XCTAssertTrue(community.contentOptions.post.enablePolls)
        XCTAssertTrue(community.contentOptions.comment.enablePictures)
        XCTAssertTrue(community.contentOptions.reply.enablePictures)
    }

    func testMissingFieldsWithinContentOptionsDefaultToEnabled() {
        // contentOptions present, but post sets only enablePictures, and comment/reply absent.
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.contentOptions = .with {
                $0.post = .with { $0.enablePictures = false } // enablePolls left unset
            }
        }

        let community = CommunityConfig(from: config)

        XCTAssertFalse(community.contentOptions.post.enablePictures)
        XCTAssertTrue(community.contentOptions.post.enablePolls)      // unset ⇒ true
        XCTAssertTrue(community.contentOptions.comment.enablePictures) // absent ⇒ true
        XCTAssertTrue(community.contentOptions.reply.enablePictures)   // absent ⇒ true
    }

    func testContentOptionsPersistThroughDatabase() async throws {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        let db = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)

        let options = ContentOptions(
            post: .init(enablePictures: false, enablePolls: false),
            comment: .init(enablePictures: true),
            reply: .init(enablePictures: false))
        let config = CommunityConfig(forceLoginOnStrongActions: false, displayAccountAge: false,
                                     gamificationConfig: nil, displayConfig: nil,
                                     profileFieldsLock: .allEditable, contentOptions: options)
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertEqual(stored.contentOptions, options)
    }

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
