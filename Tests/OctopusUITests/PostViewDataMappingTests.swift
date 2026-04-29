//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Testing
@testable import OctopusUI
import OctopusCore

@Suite
struct PostViewDataMappingTests {

    // MARK: - Moderation tag

    @Test func moderatedPost_setsModeratedTag() async throws {
        let post = Self.makeDisplayable(contentKind: .moderated)
        let viewData = PostViewData(from: post)
        #expect(viewData.tags == [.moderated])
    }

    @Test func publishedPost_hasNoTagByDefault() async throws {
        let post = Self.makeDisplayable(contentKind: .textOnly)
        let viewData = PostViewData(from: post)
        #expect(viewData.tags.isEmpty)
    }

    // MARK: - CTA collapsing

    @Test func bridgePost_collapsesToBridgeCTA() async throws {
        let post = Self.makeDisplayable(contentKind: .bridgeWithCTA)
        let viewData = PostViewData(from: post)
        guard case let .published(content) = viewData.content else {
            Issue.record("expected published content")
            return
        }
        guard case let .bridge(objectId) = content.cta?.action else {
            Issue.record("expected bridge cta")
            return
        }
        #expect(objectId == "clientObjectId")
    }

    @Test func customActionPost_collapsesToOpenURLCTA() async throws {
        let url = URL(string: "https://example.com")!
        let post = Self.makeDisplayable(contentKind: .customAction(url: url))
        let viewData = PostViewData(from: post)
        guard case let .published(content) = viewData.content else {
            Issue.record("expected published content")
            return
        }
        guard case let .openURL(target) = content.cta?.action else {
            Issue.record("expected openURL cta")
            return
        }
        #expect(target == url)
    }

    @Test func plainPost_hasNoCTA() async throws {
        let post = Self.makeDisplayable(contentKind: .textOnly)
        let viewData = PostViewData(from: post)
        guard case let .published(content) = viewData.content else {
            Issue.record("expected published content")
            return
        }
        #expect(content.cta == nil)
    }

    // MARK: - Topic mapping

    @Test func topic_preserved() async throws {
        let post = Self.makeDisplayable(contentKind: .textOnly, topic: "Help")
        let viewData = PostViewData(from: post)
        #expect(viewData.topic == "Help")
    }

    // MARK: - PostDetailViewModel.Post → PostViewData (detail-side)

    @Test func detailMapping_preservesCoreFields() async throws {
        let post = Self.makeDetailPost(uuid: "post-42", topic: "Tech")
        let viewData = PostViewData(from: post)
        #expect(viewData.uuid == "post-42")
        #expect(viewData.topic == "Tech")
        #expect(viewData.canBeDeleted == false)
        #expect(viewData.canBeModerated == true)
    }

    @Test func detailMapping_wrapsTextAsNonEllipsized() async throws {
        let post = Self.makeDetailPost(text: "Long detail body text.")
        let viewData = PostViewData(from: post)
        guard case let .published(content) = viewData.content else {
            Issue.record("expected published content")
            return
        }
        #expect(content.text.getText(translated: false) == "Long detail body text.")
        #expect(content.text.getIsEllipsized(translated: false) == false)
    }

    @Test func detailMapping_bridgeCTA_takesPrecedenceOverCustomAction() async throws {
        let post = Self.makeDetailPost(
            bridgeCTA: .init(
                text: TranslatableText(originalText: "Open", originalLanguage: nil),
                clientObjectId: "obj-1"),
            customAction: .init(
                ctaText: TranslatableText(originalText: "Visit", originalLanguage: nil),
                targetUrl: URL(string: "https://example.com")!))
        let viewData = PostViewData(from: post)
        guard case let .published(content) = viewData.content,
              case let .bridge(objectId) = content.cta?.action else {
            Issue.record("expected bridge cta")
            return
        }
        #expect(objectId == "obj-1")
    }

    @Test func detailMapping_customAction_collapsesToOpenURLCTA() async throws {
        let url = URL(string: "https://example.com/detail")!
        let post = Self.makeDetailPost(
            customAction: .init(
                ctaText: TranslatableText(originalText: "Visit", originalLanguage: nil),
                targetUrl: url))
        let viewData = PostViewData(from: post)
        guard case let .published(content) = viewData.content,
              case let .openURL(target) = content.cta?.action else {
            Issue.record("expected openURL cta")
            return
        }
        #expect(target == url)
    }

    @Test func detailMapping_noBridgeNoCustom_hasNoCTA() async throws {
        let post = Self.makeDetailPost()
        let viewData = PostViewData(from: post)
        guard case let .published(content) = viewData.content else {
            Issue.record("expected published content")
            return
        }
        #expect(content.cta == nil)
    }

    @Test func detailMapping_buildsLiveMeasuresSnapshotFromAggregatedInfo() async throws {
        let aggregated = AggregatedInfo(reactions: [
            .init(reactionKind: .heart, count: 3)
        ], childCount: 4, viewCount: 0, pollResult: nil)
        let post = Self.makeDetailPost(aggregatedInfo: aggregated)
        let viewData = PostViewData(from: post)
        guard case let .published(content) = viewData.content else {
            Issue.record("expected published content")
            return
        }
        #expect(content.liveMeasuresValue.aggregatedInfo.childCount == 4)
        #expect(content.liveMeasuresValue.aggregatedInfo.reactions.first?.count == 3)
    }

    @Test func detailMapping_tagsAlwaysEmpty() async throws {
        // The detail screen is only opened for published posts (moderated posts don't drill
        // in), so the mapping doesn't need a `.moderated` tag. Pin that invariant.
        let post = Self.makeDetailPost()
        let viewData = PostViewData(from: post)
        #expect(viewData.tags.isEmpty)
    }

    // MARK: - canBeBlockedByUser forwarding

    @Test func test_postViewData_forwardsCanBeBlockedByUser() async throws {
        let truePost = Self.makeDisplayable(contentKind: .textOnly, canBeBlockedByUser: true)
        #expect(PostViewData(from: truePost).canBeBlockedByUser == true)

        let falsePost = Self.makeDisplayable(contentKind: .textOnly, canBeBlockedByUser: false)
        #expect(PostViewData(from: falsePost).canBeBlockedByUser == false)
    }

    // MARK: - Fixtures

    enum ContentKind {
        case textOnly
        case bridgeWithCTA
        case customAction(url: URL)
        case moderated
    }

    static func makeDisplayable(
        contentKind: ContentKind,
        topic: String = "Help",
        canBeBlockedByUser: Bool = false
    ) -> DisplayablePost {
        let author = Author(
            profile: MinimalProfile(
                uuid: "profileId",
                nickname: "Bobby",
                avatarUrl: URL(string: "https://example.com/avatar.jpg")!,
                gamificationLevel: 1),
            gamificationLevel: GamificationLevel(
                level: 1, name: "", startAt: 0, nextLevelAt: 100,
                badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000")))

        let emptyMeasures = CurrentValueSubject<LiveMeasures, Never>(
            LiveMeasures(
                aggregatedInfo: .init(reactions: [], childCount: 0, viewCount: 0, pollResult: nil),
                userInteractions: .empty))

        let content: DisplayablePost.Content
        switch contentKind {
        case .textOnly:
            content = .published(.init(
                text: .init(originalText: "Un texte", originalLanguage: nil),
                attachment: nil, bridgeInfo: nil, customAction: nil, featuredComment: nil,
                liveMeasuresPublisher: emptyMeasures))
        case .bridgeWithCTA:
            content = .published(.init(
                text: .init(originalText: "Un texte", originalLanguage: nil),
                attachment: .image(.init(url: URL(string: "https://example.com/i.jpg")!,
                                        size: CGSize(width: 700, height: 750))),
                bridgeInfo: .init(
                    objectId: "clientObjectId",
                    catchPhrase: .init(originalText: "Catch", originalLanguage: nil),
                    ctaText: .init(originalText: "View", originalLanguage: nil)),
                customAction: nil, featuredComment: nil,
                liveMeasuresPublisher: emptyMeasures))
        case let .customAction(url):
            content = .published(.init(
                text: .init(originalText: "Un texte", originalLanguage: nil),
                attachment: nil, bridgeInfo: nil,
                customAction: .init(
                    ctaText: .init(originalText: "Voir", originalLanguage: nil),
                    targetUrl: url),
                featuredComment: nil,
                liveMeasuresPublisher: emptyMeasures))
        case .moderated:
            content = .moderated(reasons: [.localizedString("Reason")])
        }

        return DisplayablePost(
            uuid: "postUuid",
            author: author,
            relativeDate: "3d ago",
            topic: topic,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: canBeBlockedByUser,
            canBeOpened: true,
            content: content,
            position: 1,
            isLast: false,
            displayEvents: .init(onAppear: {}, onDisappear: {}))
    }

    static func makeDetailPost(
        uuid: String = "post-uuid",
        text: String = "Some detail text",
        topic: String = "Help",
        attachment: PostDetailViewModel.Post.Attachment? = nil,
        bridgeCTA: PostDetailViewModel.Post.BridgeCTA? = nil,
        customAction: PostDetailViewModel.Post.CustomAction? = nil,
        aggregatedInfo: AggregatedInfo = .init(
            reactions: [], childCount: 0, viewCount: 0, pollResult: nil)
    ) -> PostDetailViewModel.Post {
        let author = Author(
            profile: MinimalProfile(
                uuid: "profileId",
                nickname: "Bobby",
                avatarUrl: URL(string: "https://example.com/avatar.jpg")!,
                gamificationLevel: 1),
            gamificationLevel: nil)
        return PostDetailViewModel.Post(
            uuid: uuid,
            text: TranslatableText(originalText: text, originalLanguage: nil),
            attachment: attachment,
            author: author,
            relativeDate: "3d ago",
            topic: topic,
            aggregatedInfo: aggregatedInfo,
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: false,
            catchPhrase: nil,
            bridgeCTA: bridgeCTA,
            customAction: customAction)
    }
}
