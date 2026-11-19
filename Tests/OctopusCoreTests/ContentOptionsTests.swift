//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import Combine
import OctopusGrpcModels
import OctopusDependencyInjection
@testable import OctopusCore

/// Mapping of the gRPC `ContentOptions` onto the `CommunityConfig` domain model.
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
        XCTAssertTrue(community.contentOptions.post.textRequired)
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
        XCTAssertTrue(community.contentOptions.post.textRequired)      // unset ⇒ true
    }

    func testTextRequiredFalseMappedFromProto() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.contentOptions = .with {
                $0.post = .with { $0.textRequired = false }
            }
        }

        let community = CommunityConfig(from: config)

        XCTAssertFalse(community.contentOptions.post.textRequired)
        XCTAssertTrue(community.contentOptions.post.enablePictures) // unset ⇒ true
        XCTAssertTrue(community.contentOptions.post.enablePolls)    // unset ⇒ true
    }

    func testTextRequiredTrueMappedFromProto() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.contentOptions = .with {
                $0.post = .with { $0.textRequired = true }
            }
        }

        let community = CommunityConfig(from: config)

        XCTAssertTrue(community.contentOptions.post.textRequired)
    }

    func testTextRequiredDefaultsToTrueWhenPostConfigIsAbsent() {
        // contentOptions present, post sub-message absent.
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.contentOptions = .with {
                $0.comment = .with { $0.enablePictures = false }
            }
        }

        let community = CommunityConfig(from: config)

        XCTAssertTrue(community.contentOptions.post.textRequired)
    }

    func testPostOptionsKeepTextRequiredByDefault() {
        // The public initializer gained `textRequired` with a default: existing call sites keep today's behaviour.
        XCTAssertTrue(ContentOptions.PostOptions(enablePictures: false, enablePolls: false).textRequired)
        XCTAssertTrue(ContentOptions.allEnabled.post.textRequired)
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
                                     profileFieldsLock: .allEditable, contentOptions: options,
                                     exposeClientUserId: false, termsAcceptanceMode: .implicit,
                                     showCommentsOnOtherProfiles: false, forceNicknameChoice: false, consentTexts: nil,
                                     informalLanguages: [])
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertEqual(stored.contentOptions, options)
    }

    func testTextRequiredPersistsThroughDatabase() async throws {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        let db = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)

        let options = ContentOptions(
            post: .init(enablePictures: true, enablePolls: true, textRequired: false),
            comment: .init(enablePictures: true),
            reply: .init(enablePictures: true))
        let config = CommunityConfig(forceLoginOnStrongActions: false, displayAccountAge: false,
                                     gamificationConfig: nil, displayConfig: nil,
                                     profileFieldsLock: .allEditable, contentOptions: options,
                                     exposeClientUserId: false, termsAcceptanceMode: .implicit,
                                     showCommentsOnOtherProfiles: false, forceNicknameChoice: false, consentTexts: nil,
                                     informalLanguages: [])
        try await db.upsert(config: config)

        let stored = try await firstNonNil(db.configPublisher())
        XCTAssertFalse(stored.contentOptions.post.textRequired)
        XCTAssertEqual(stored.contentOptions, options)
    }

    // MARK: - Post tap options (absent ⇒ false)

    func testPostTapOptionsDefaultToFalseWhenConfigPostOrFieldsAreAbsent() {
        let configs = [
            Com_Octopuscommunity_ApiKeyConfig.with { $0.displayAccountAge = true },
            Com_Octopuscommunity_ApiKeyConfig.with { $0.contentOptions = .with { _ in } },
            Com_Octopuscommunity_ApiKeyConfig.with { $0.contentOptions = .with { $0.post = .with { _ in } } },
        ]
        for config in configs {
            let post = CommunityConfig(from: config).contentOptions.post
            XCTAssertFalse(post.imageTapOpensPost)
            XCTAssertFalse(post.groupNameTapOpensGroup)
            XCTAssertTrue(post.enablePictures)
            XCTAssertTrue(post.enablePolls)
            XCTAssertTrue(post.textRequired)
        }
    }

    func testPostTapOptionsMapIndependentlyIncludingExplicitFalseOverTheWire() throws {
        for image in [false, true] {
            for group in [false, true] {
                let config = Com_Octopuscommunity_ApiKeyConfig.with {
                    $0.contentOptions = .with {
                        $0.post = .with {
                            $0.imageTapOpensPost = image
                            $0.groupNameTapOpensGroup = group
                            $0.enablePictures = false
                            $0.textRequired = false
                        }
                    }
                }
                // Round trip through the wire format: an explicit `false` must stay present.
                let bytes: [UInt8] = try config.serializedBytes()
                let parsed = try Com_Octopuscommunity_ApiKeyConfig(serializedBytes: bytes)
                XCTAssertTrue(parsed.contentOptions.post.hasImageTapOpensPost)
                XCTAssertTrue(parsed.contentOptions.post.hasGroupNameTapOpensGroup)

                let post = CommunityConfig(from: parsed).contentOptions.post
                XCTAssertEqual(post.imageTapOpensPost, image)
                XCTAssertEqual(post.groupNameTapOpensGroup, group)
                XCTAssertFalse(post.enablePictures)
                XCTAssertFalse(post.textRequired)
                XCTAssertTrue(post.enablePolls)
            }
        }
    }

    func testExistingPostOptionsInitializersKeepTapOptionsDisabled() {
        // The public initializer gained the tap options with defaults: existing call sites keep today's navigation.
        for post in [ContentOptions.PostOptions(enablePictures: false, enablePolls: true),
                     ContentOptions.PostOptions(enablePictures: false, enablePolls: true, textRequired: false),
                     ContentOptions.allEnabled.post] {
            XCTAssertFalse(post.imageTapOpensPost)
            XCTAssertFalse(post.groupNameTapOpensGroup)
        }
    }

    func testPostTapOptionsTakePartInValueSemantics() {
        let values = [(false, false), (true, false), (false, true), (true, true)].map {
            ContentOptions.PostOptions(enablePictures: true, enablePolls: true,
                                       imageTapOpensPost: $0.0, groupNameTapOpensGroup: $0.1)
        }
        XCTAssertEqual(Set(values).count, 4)
    }

    func testPostTapOptionsPersistThroughDatabase() async throws {
        for image in [false, true] {
            for group in [false, true] {
                let injector = Injector()
                injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
                injector.register { CommunityConfigDatabase(injector: $0) }
                let db = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)

                let options = ContentOptions(
                    post: .init(enablePictures: true, enablePolls: true, textRequired: true,
                                imageTapOpensPost: image, groupNameTapOpensGroup: group),
                    comment: .init(enablePictures: true),
                    reply: .init(enablePictures: true))
                let config = CommunityConfig(forceLoginOnStrongActions: false, displayAccountAge: false,
                                             gamificationConfig: nil, displayConfig: nil,
                                             profileFieldsLock: .allEditable, contentOptions: options,
                                             exposeClientUserId: false, termsAcceptanceMode: .implicit,
                                             showCommentsOnOtherProfiles: false, forceNicknameChoice: false,
                                             consentTexts: nil, informalLanguages: [])
                try await db.upsert(config: config)

                let stored = try await firstNonNil(db.configPublisher())
                XCTAssertEqual(stored.contentOptions.post.imageTapOpensPost, image)
                XCTAssertEqual(stored.contentOptions.post.groupNameTapOpensGroup, group)
                XCTAssertEqual(stored.contentOptions, options)
            }
        }
    }

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
}
