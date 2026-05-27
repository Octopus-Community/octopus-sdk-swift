//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore
import OctopusDependencyInjection
@testable import OctopusUI

@Suite(.serialized)
struct GroupDetailMappingTests {

    @Test
    func mappingFromTopic_withCustomAction_propagatesFields() {
        let topic = makeTopic(customAction: CustomAction(
            ctaText: TranslatableText(originalText: "Voir", originalLanguage: nil, translatedText: nil),
            targetUrl: URL(string: "myapp://x")!))
        let detail = GroupDetail(from: topic)
        #expect(detail.customAction != nil)
        #expect(detail.customAction?.ctaText.originalText == "Voir")
        #expect(detail.customAction?.targetUrl == URL(string: "myapp://x"))
    }

    @Test
    func mappingFromTopic_withNoCustomAction_returnsNil() {
        let topic = makeTopic(customAction: nil)
        let detail = GroupDetail(from: topic)
        #expect(detail.customAction == nil)
    }

    private func makeTopic(customAction: CustomAction?) -> Topic {
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
        let postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)

        let storable = StorableTopic(
            uuid: "topic-1",
            name: "Topic",
            description: "",
            followStatus: .notFollowed,
            sections: [],
            feedId: "feed-1",
            permissions: .default,
            customActionText: customAction?.ctaText,
            customActionTargetLink: customAction?.targetUrl.absoluteString)
        return Topic(from: storable, postFeedsStore: postFeedsStore)
    }
}

@Suite
struct GroupCTAContentViewTapTests {

    final class FakeTrackingApi: TrackingApi, @unchecked Sendable {
        var trackedGroupIds: [String] = []
        var trackedPostIds: [String] = []
        var translationCalls: [Bool] = []
        var emittedEvents: [SdkEvent] = []
        func trackTranslationButtonHit(translationDisplayed: Bool) { translationCalls.append(translationDisplayed) }
        func trackPostCustomActionButtonHit(postId: String) { trackedPostIds.append(postId) }
        func trackGroupCustomActionButtonHit(groupId: String) { trackedGroupIds.append(groupId) }
        func emit(event: SdkEvent) { emittedEvents.append(event) }
    }

    @MainActor
    final class FakeURLOpener: URLOpening, @unchecked Sendable {
        var openedUrls: [URL] = []
        func open(url: URL) { openedUrls.append(url) }
    }

    @Test
    @MainActor
    func handleTap_callsTrackingAndUrlOpenerOnceEach() {
        let tracking = FakeTrackingApi()
        let opener = FakeURLOpener()
        let url = URL(string: "myapp://x")!

        GroupCTAContentView.handleTap(
            groupId: "topic-1", targetUrl: url, trackingApi: tracking, urlOpener: opener)

        #expect(tracking.trackedGroupIds == ["topic-1"])
        #expect(opener.openedUrls == [url])
    }

    @Test
    @MainActor
    func handleTap_calledTwice_emitsTwoOfEach() {
        let tracking = FakeTrackingApi()
        let opener = FakeURLOpener()
        let url = URL(string: "myapp://x")!

        GroupCTAContentView.handleTap(
            groupId: "topic-1", targetUrl: url, trackingApi: tracking, urlOpener: opener)
        GroupCTAContentView.handleTap(
            groupId: "topic-1", targetUrl: url, trackingApi: tracking, urlOpener: opener)

        #expect(tracking.trackedGroupIds.count == 2)
        #expect(opener.openedUrls.count == 2)
    }
}
