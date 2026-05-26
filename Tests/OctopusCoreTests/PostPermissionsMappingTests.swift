//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

struct PostPermissionsMappingTests {
    @Test func absentRequesterCtxDefaultsToOpen() {
        let octoPost = Com_Octopuscommunity_OctoObject.with {
            $0.id = "p1"
            $0.parentID = "topicId"
            $0.content = .with {
                $0.post = .with { $0.text = "hello" }
            }
            $0.status = .with { $0.value = .published }
        }
        let storable = StorablePost(octoPost: octoPost, aggregate: nil, userInteraction: nil)
        #expect(storable?.permissions.canAccess == true)
        #expect(storable?.permissions.canCreateChildren == true)
    }

    @Test func canAccessFalseFromRequesterCtx() {
        let octoPost = Com_Octopuscommunity_OctoObject.with {
            $0.id = "p1"
            $0.parentID = "topicId"
            $0.content = .with {
                $0.post = .with { $0.text = "hello" }
            }
            $0.status = .with { $0.value = .published }
        }
        let ctx = Com_Octopuscommunity_RequesterCtx.with {
            $0.canAccess = false
            $0.canCreateChildren = false
        }
        let storable = StorablePost(octoPost: octoPost, aggregate: nil, userInteraction: ctx)
        #expect(storable?.permissions.canAccess == false)
        #expect(storable?.permissions.canCreateChildren == false)
    }

    @Test func canAccessTrueButCannotCreateChildren() {
        let octoPost = Com_Octopuscommunity_OctoObject.with {
            $0.id = "p1"
            $0.parentID = "topicId"
            $0.content = .with {
                $0.post = .with { $0.text = "hello" }
            }
            $0.status = .with { $0.value = .published }
        }
        let ctx = Com_Octopuscommunity_RequesterCtx.with {
            $0.canAccess = true
            $0.canCreateChildren = false
        }
        let storable = StorablePost(octoPost: octoPost, aggregate: nil, userInteraction: ctx)
        #expect(storable?.permissions.canAccess == true)
        #expect(storable?.permissions.canCreateChildren == false)
    }

    @Test @MainActor func entityRoundTripPreservesPermissions() async throws {
        let stack = try ModelCoreDataStack(inRam: true)
        let context = stack.viewContext

        let storable = StorablePost(
            uuid: "p1",
            text: TranslatableText(originalText: "hello", originalLanguage: nil, translatedText: nil),
            medias: [],
            poll: nil,
            author: nil,
            creationDate: Date(timeIntervalSince1970: 0),
            updateDate: Date(timeIntervalSince1970: 0),
            status: .published,
            statusReasons: [],
            parentId: "topicId",
            descCommentFeedId: nil,
            ascCommentFeedId: nil,
            bridgeClientObjectId: nil,
            bridgeCatchPhrase: nil,
            bridgeCtaText: nil,
            customActionText: nil,
            customActionTargetLink: nil,
            aggregatedInfo: nil,
            userInteractions: nil,
            permissions: UserPermissions(canAccess: false, canCreateChildren: false)
        )

        let entity = PostEntity(context: context)
        try entity.fill(with: storable, context: context)
        try context.save()

        let roundTripped = StorablePost(from: entity)
        #expect(roundTripped.permissions.canAccess == false)
        #expect(roundTripped.permissions.canCreateChildren == false)
    }

    /// Regression for the bug where creating a post in a closed-to-comments group kept
    /// `canCreateChildren = true` in the DB: after `send()` upserts with default-open
    /// permissions, the cell's `fetchAdditionalData` (additional-data path) must persist
    /// the up-to-date permissions carried by the response's `RequesterCtx`.
    @Test @MainActor func additionalDataPathOverwritesPermissions() async throws {
        let stack = try ModelCoreDataStack(inRam: true)
        let context = stack.viewContext

        let initialStorable = StorablePost(
            uuid: "p1",
            text: TranslatableText(originalText: "hello", originalLanguage: nil, translatedText: nil),
            medias: [], poll: nil, author: nil,
            creationDate: Date(timeIntervalSince1970: 0),
            updateDate: Date(timeIntervalSince1970: 0),
            status: .published, statusReasons: [],
            parentId: "topicId",
            descCommentFeedId: nil, ascCommentFeedId: nil,
            bridgeClientObjectId: nil, bridgeCatchPhrase: nil, bridgeCtaText: nil,
            customActionText: nil, customActionTargetLink: nil,
            aggregatedInfo: nil, userInteractions: nil,
            permissions: .default
        )
        let entity = PostEntity(context: context)
        try entity.fill(with: initialStorable, context: context)
        try context.save()

        entity.fill(aggregatedInfo: nil, userInteractions: nil,
                    permissions: UserPermissions(canAccess: true, canCreateChildren: false),
                    context: context)
        try context.save()

        let roundTripped = StorablePost(from: entity)
        #expect(roundTripped.permissions.canAccess == true)
        #expect(roundTripped.permissions.canCreateChildren == false)
    }

    /// When the additional-data path passes `permissions: nil` (no `RequesterCtx` in the
    /// response), the existing stored permissions must not be clobbered.
    @Test @MainActor func additionalDataPathLeavesPermissionsUntouchedWhenNil() async throws {
        let stack = try ModelCoreDataStack(inRam: true)
        let context = stack.viewContext

        let initialStorable = StorablePost(
            uuid: "p1",
            text: TranslatableText(originalText: "hello", originalLanguage: nil, translatedText: nil),
            medias: [], poll: nil, author: nil,
            creationDate: Date(timeIntervalSince1970: 0),
            updateDate: Date(timeIntervalSince1970: 0),
            status: .published, statusReasons: [],
            parentId: "topicId",
            descCommentFeedId: nil, ascCommentFeedId: nil,
            bridgeClientObjectId: nil, bridgeCatchPhrase: nil, bridgeCtaText: nil,
            customActionText: nil, customActionTargetLink: nil,
            aggregatedInfo: nil, userInteractions: nil,
            permissions: UserPermissions(canAccess: false, canCreateChildren: false)
        )
        let entity = PostEntity(context: context)
        try entity.fill(with: initialStorable, context: context)
        try context.save()

        entity.fill(aggregatedInfo: nil, userInteractions: nil, permissions: nil, context: context)
        try context.save()

        let roundTripped = StorablePost(from: entity)
        #expect(roundTripped.permissions.canAccess == false)
        #expect(roundTripped.permissions.canCreateChildren == false)
    }
}
