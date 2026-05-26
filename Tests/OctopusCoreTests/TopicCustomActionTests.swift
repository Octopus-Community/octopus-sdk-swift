//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusDependencyInjection
import OctopusGrpcModels
@testable import OctopusCore

@Suite(.serialized)
struct TopicCustomActionDecodeTests {

    @Test
    func decodeNoCtaField_returnsNilCustomAction() {
        let octo = makeOctoTopic(setCta: false)
        let storable = StorableTopic(from: octo, requesterCtx: nil, sections: [])
        #expect(storable != nil)
        #expect(storable?.customActionText == nil)
        #expect(storable?.customActionTargetLink == nil)
    }

    @Test
    func decodeCtaWithTextAndTargetLink_populatesFields() {
        let octo = makeOctoTopic(setCta: true, text: "Voir l'offre", targetLink: "myapp://deal/42")
        let storable = StorableTopic(from: octo, requesterCtx: nil, sections: [])
        #expect(storable != nil)
        #expect(storable?.customActionText?.originalText == "Voir l'offre")
        #expect(storable?.customActionText?.translatedText == nil)
        #expect(storable?.customActionTargetLink == "myapp://deal/42")
    }

    @Test
    func decodeCtaWithTranslatedText_propagatesTranslation() {
        let octo = makeOctoTopic(setCta: true, text: "Voir l'offre", translatedText: "See offer",
                                 targetLink: "myapp://x")
        let storable = StorableTopic(from: octo, requesterCtx: nil, sections: [])
        #expect(storable != nil)
        #expect(storable?.customActionText?.originalText == "Voir l'offre")
        #expect(storable?.customActionText?.translatedText == "See offer")
        #expect(storable?.customActionTargetLink == "myapp://x")
    }

    @Test
    func decodeCtaWithEmptyText_returnsNil() {
        let octo = makeOctoTopic(setCta: true, text: "", targetLink: "myapp://x")
        let storable = StorableTopic(from: octo, requesterCtx: nil, sections: [])
        #expect(storable != nil)
        #expect(storable?.customActionText == nil)
        #expect(storable?.customActionTargetLink == nil)
    }

    @Test
    func decodeCtaWithWhitespaceOnlyText_returnsNil() {
        let octo = makeOctoTopic(setCta: true, text: "   \n  ", targetLink: "myapp://x")
        let storable = StorableTopic(from: octo, requesterCtx: nil, sections: [])
        #expect(storable != nil)
        #expect(storable?.customActionText == nil)
        #expect(storable?.customActionTargetLink == nil)
    }

    @Test
    func decodeCtaWithEmptyTargetLink_returnsNil() {
        let octo = makeOctoTopic(setCta: true, text: "Voir", targetLink: "")
        let storable = StorableTopic(from: octo, requesterCtx: nil, sections: [])
        #expect(storable != nil)
        #expect(storable?.customActionText == nil)
        #expect(storable?.customActionTargetLink == nil)
    }

    // MARK: - Topic.init(from: StorableTopic) URL-guard tests

    @Test
    func topicInit_withValidTextAndUrl_populatesCustomAction() {
        let injector = makeInjector()
        let postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)
        let translatableText = TranslatableText(originalText: "Voir l'offre", originalLanguage: nil,
                                                translatedText: nil)
        let storable = StorableTopic(uuid: "t1", name: "T", description: "",
                                     followStatus: .followed, sections: [], feedId: "feed-1",
                                     customActionText: translatableText,
                                     customActionTargetLink: "myapp://x")
        let topic = Topic(from: storable, postFeedsStore: postFeedsStore)
        #expect(topic.customAction != nil)
        #expect(topic.customAction?.ctaText.originalText == "Voir l'offre")
        #expect(topic.customAction?.targetUrl == URL(string: "myapp://x"))
    }

    @Test
    func topicInit_withNilFields_returnsNilCustomAction() {
        let injector = makeInjector()
        let postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)
        let storable = StorableTopic(uuid: "t1", name: "T", description: "",
                                     followStatus: .followed, sections: [], feedId: "feed-1",
                                     customActionText: nil,
                                     customActionTargetLink: nil)
        let topic = Topic(from: storable, postFeedsStore: postFeedsStore)
        #expect(topic.customAction == nil)
    }

    // MARK: - Helpers

    private func makeOctoTopic(setCta: Bool = true,
                               text: String = "",
                               translatedText: String? = nil,
                               targetLink: String = "") -> Com_Octopuscommunity_OctoObject {
        .with {
            $0.id = "topic-1"
            $0.content = .with {
                $0.topic = .with {
                    $0.name = "Topic"
                    $0.description_p = ""
                    if setCta {
                        $0.cta = .with {
                            $0.text = text
                            if let translatedText {
                                $0.translatedText = translatedText
                            }
                            $0.targetLink = targetLink
                        }
                    }
                }
            }
        }
    }

    private func makeInjector() -> Injector {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.registerMocks(.remoteClient, .networkMonitor, .authProvider, .blockedUserIdsProvider)
        return injector
    }
}

@Suite(.serialized)
struct TopicCustomActionPersistenceTests {

    @Test
    func roundTrip_withNonNilCta_preservesAllColumns() async throws {
        let coreDataStack = try ModelCoreDataStack(inRam: true)
        let context = coreDataStack.saveContext

        let translatableText = TranslatableText(originalText: "Voir l'offre", originalLanguage: nil,
                                                translatedText: "See offer")
        let storable = StorableTopic(uuid: "topic-1", name: "T", description: "Desc",
                                     followStatus: .followed, sections: [], feedId: "feed-1",
                                     customActionText: translatableText,
                                     customActionTargetLink: "myapp://x")

        try await context.performAsync { [context] in
            let entity = TopicEntity(context: context)
            try entity.fill(with: storable, position: 0, context: context)
            try context.save()
        }

        let refetched: StorableTopic? = try await context.performAsync { [context] in
            guard let entity = try context.fetch(TopicEntity.fetchById(id: "topic-1")).first else {
                return nil
            }
            return StorableTopic(from: entity)
        }

        #expect(refetched != nil)
        #expect(refetched?.customActionText?.originalText == "Voir l'offre")
        #expect(refetched?.customActionText?.translatedText == "See offer")
        #expect(refetched?.customActionTargetLink == "myapp://x")
    }

    @Test
    func roundTrip_withNilCta_keepsAllColumnsNil() async throws {
        let coreDataStack = try ModelCoreDataStack(inRam: true)
        let context = coreDataStack.saveContext

        let storable = StorableTopic(uuid: "topic-2", name: "T", description: "Desc",
                                     followStatus: .followed, sections: [], feedId: "feed-2",
                                     customActionText: nil,
                                     customActionTargetLink: nil)

        try await context.performAsync { [context] in
            let entity = TopicEntity(context: context)
            try entity.fill(with: storable, position: 0, context: context)
            try context.save()
        }

        let refetched: StorableTopic? = try await context.performAsync { [context] in
            guard let entity = try context.fetch(TopicEntity.fetchById(id: "topic-2")).first else {
                return nil
            }
            return StorableTopic(from: entity)
        }

        #expect(refetched != nil)
        #expect(refetched?.customActionText == nil)
        #expect(refetched?.customActionTargetLink == nil)
    }
}
