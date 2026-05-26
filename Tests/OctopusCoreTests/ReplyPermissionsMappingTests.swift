//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

struct ReplyPermissionsMappingTests {
    @Test func absentRequesterCtxDefaultsToOpen() {
        let octoReply = Com_Octopuscommunity_OctoObject.with {
            $0.id = "r1"
            $0.parentID = "commentId"
            $0.content = .with {
                $0.reply = .with { $0.text = "hello" }
            }
            $0.status = .with { $0.value = .published }
        }
        let storable = StorableReply(octoReply: octoReply, aggregate: nil, userInteraction: nil)
        #expect(storable?.permissions.canAccess == true)
        #expect(storable?.permissions.canCreateChildren == true)
    }

    @Test func canAccessFalseFromRequesterCtx() {
        let octoReply = Com_Octopuscommunity_OctoObject.with {
            $0.id = "r1"
            $0.parentID = "commentId"
            $0.content = .with {
                $0.reply = .with { $0.text = "hello" }
            }
            $0.status = .with { $0.value = .published }
        }
        let ctx = Com_Octopuscommunity_RequesterCtx.with {
            $0.canAccess = false
            $0.canCreateChildren = false
        }
        let storable = StorableReply(octoReply: octoReply, aggregate: nil, userInteraction: ctx)
        #expect(storable?.permissions.canAccess == false)
        #expect(storable?.permissions.canCreateChildren == false)
    }

    @Test func canAccessTrueButCannotCreateChildren() {
        let octoReply = Com_Octopuscommunity_OctoObject.with {
            $0.id = "r1"
            $0.parentID = "commentId"
            $0.content = .with {
                $0.reply = .with { $0.text = "hello" }
            }
            $0.status = .with { $0.value = .published }
        }
        let ctx = Com_Octopuscommunity_RequesterCtx.with {
            $0.canAccess = true
            $0.canCreateChildren = false
        }
        let storable = StorableReply(octoReply: octoReply, aggregate: nil, userInteraction: ctx)
        #expect(storable?.permissions.canAccess == true)
        #expect(storable?.permissions.canCreateChildren == false)
    }

    @Test @MainActor func entityRoundTripPreservesPermissions() async throws {
        let stack = try ModelCoreDataStack(inRam: true)
        let context = stack.viewContext

        let storable = StorableReply(
            uuid: "r1",
            text: TranslatableText(originalText: "hello", originalLanguage: nil, translatedText: nil),
            medias: [],
            author: nil,
            creationDate: Date(timeIntervalSince1970: 0),
            updateDate: Date(timeIntervalSince1970: 0),
            status: .published,
            statusReasons: [],
            parentId: "commentId",
            aggregatedInfo: nil,
            userInteractions: nil,
            permissions: UserPermissions(canAccess: false, canCreateChildren: false)
        )

        let entity = ReplyEntity(context: context)
        try entity.fill(with: storable, context: context)
        try context.save()

        let roundTripped = StorableReply(from: entity)
        #expect(roundTripped.permissions.canAccess == false)
        #expect(roundTripped.permissions.canCreateChildren == false)
    }

    /// The additional-data path (cell `onAppear` → `RepliesRepository.fetchAdditionalData`)
    /// must persist the `RequesterCtx` permissions, not just the reaction/poll bits.
    @Test @MainActor func additionalDataPathOverwritesPermissions() async throws {
        let stack = try ModelCoreDataStack(inRam: true)
        let context = stack.viewContext

        let initialStorable = StorableReply(
            uuid: "r1",
            text: TranslatableText(originalText: "hello", originalLanguage: nil, translatedText: nil),
            medias: [], author: nil,
            creationDate: Date(timeIntervalSince1970: 0),
            updateDate: Date(timeIntervalSince1970: 0),
            status: .published, statusReasons: [],
            parentId: "commentId",
            aggregatedInfo: nil, userInteractions: nil,
            permissions: .default
        )
        let entity = ReplyEntity(context: context)
        try entity.fill(with: initialStorable, context: context)
        try context.save()

        entity.fill(aggregatedInfo: nil, userInteractions: nil,
                    permissions: UserPermissions(canAccess: true, canCreateChildren: false),
                    context: context)
        try context.save()

        let roundTripped = StorableReply(from: entity)
        #expect(roundTripped.permissions.canAccess == true)
        #expect(roundTripped.permissions.canCreateChildren == false)
    }
}
