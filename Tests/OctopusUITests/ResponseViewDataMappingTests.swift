//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Testing
@testable import OctopusUI
import OctopusCore

@Suite
struct ResponseViewDataMappingTests {

    // MARK: - DisplayableFeedResponse → ResponseViewData

    @Test func mapComment_preservesKind() async throws {
        let source = Self.makeDisplayableResponse(kind: .comment)
        let mapped = ResponseViewData(from: source)
        #expect(mapped.kind == .comment)
    }

    @Test func mapReply_preservesKind() async throws {
        let source = Self.makeDisplayableResponse(kind: .reply)
        let mapped = ResponseViewData(from: source)
        #expect(mapped.kind == .reply)
    }

    @Test func mapDisplayable_preservesUuid() async throws {
        let source = Self.makeDisplayableResponse(kind: .comment, uuid: "comment-123")
        let mapped = ResponseViewData(from: source)
        #expect(mapped.uuid == "comment-123")
    }

    @Test func mapDisplayable_preservesTextWhenPresent() async throws {
        let source = Self.makeDisplayableResponse(kind: .comment, text: "Hello world")
        let mapped = ResponseViewData(from: source)
        #expect(mapped.text?.getText(translated: false) == "Hello world")
    }

    @Test func mapDisplayable_nilTextStaysNil() async throws {
        let source = Self.makeDisplayableResponse(kind: .comment, text: nil)
        let mapped = ResponseViewData(from: source)
        #expect(mapped.text == nil)
    }

    @Test func mapDisplayable_forwardsCanBeBlockedByUser() async throws {
        let trueSource = Self.makeDisplayableResponse(kind: .comment, canBeBlockedByUser: true)
        #expect(ResponseViewData(from: trueSource).canBeBlockedByUser == true)

        let falseSource = Self.makeDisplayableResponse(kind: .comment, canBeBlockedByUser: false)
        #expect(ResponseViewData(from: falseSource).canBeBlockedByUser == false)
    }

    // MARK: - CommentDetail → ResponseViewData

    @Test func mapCommentDetail_setsKindToComment() async throws {
        let source = Self.makeCommentDetail()
        let mapped = ResponseViewData(from: source)
        #expect(mapped.kind == .comment)
    }

    @Test func mapCommentDetail_preservesUuid() async throws {
        let source = Self.makeCommentDetail(uuid: "comment-42")
        let mapped = ResponseViewData(from: source)
        #expect(mapped.uuid == "comment-42")
    }

    @Test func mapCommentDetail_wrapsTextAsNonEllipsized() async throws {
        let source = Self.makeCommentDetail(text: "Detail text")
        let mapped = ResponseViewData(from: source)
        #expect(mapped.text?.getText(translated: false) == "Detail text")
        #expect(mapped.text?.getIsEllipsized(translated: false) == false)
    }

    @Test func mapCommentDetail_nilTextStaysNil() async throws {
        let source = Self.makeCommentDetail(text: nil)
        let mapped = ResponseViewData(from: source)
        #expect(mapped.text == nil)
    }

    @Test func mapCommentDetail_buildsLiveMeasuresSnapshot() async throws {
        let aggregated = AggregatedInfo(reactions: [
            .init(reactionKind: .heart, count: 5)
        ], childCount: 2, viewCount: 10, pollResult: nil)
        let source = Self.makeCommentDetail(aggregatedInfo: aggregated)
        let mapped = ResponseViewData(from: source)
        #expect(mapped.liveMeasuresValue.aggregatedInfo.childCount == 2)
        #expect(mapped.liveMeasuresValue.aggregatedInfo.reactions.count == 1)
    }

    @Test func mapCommentDetail_forwardsCanBeBlockedByUser() async throws {
        let trueSource = Self.makeCommentDetail(canBeBlockedByUser: true)
        #expect(ResponseViewData(from: trueSource).canBeBlockedByUser == true)

        let falseSource = Self.makeCommentDetail(canBeBlockedByUser: false)
        #expect(ResponseViewData(from: falseSource).canBeBlockedByUser == false)
    }

    // MARK: - Fixtures

    static func makeDisplayableResponse(
        kind: ResponseKind,
        uuid: String = "response-uuid",
        text: String? = "Some text",
        canBeBlockedByUser: Bool = false
    ) -> DisplayableFeedResponse {
        let author = Author(
            profile: MinimalProfile(
                uuid: "profile-id",
                nickname: "Bobby",
                avatarUrl: URL(string: "https://example.com/a.jpg")!,
                gamificationLevel: 1),
            gamificationLevel: nil)

        let subject = CurrentValueSubject<LiveMeasures, Never>(
            LiveMeasures(
                aggregatedInfo: .init(reactions: [], childCount: 0, viewCount: 0, pollResult: nil),
                userInteractions: .empty))

        let ellipsizable: EllipsizableTranslatedText? = text.flatMap {
            EllipsizableTranslatedText(text: TranslatableText(originalText: $0, originalLanguage: nil),
                                       ellipsize: false)
        }

        return DisplayableFeedResponse(
            kind: kind,
            uuid: uuid,
            text: ellipsizable,
            image: nil,
            author: author,
            relativeDate: "3d ago",
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: canBeBlockedByUser,
            _liveMeasuresPublisher: subject,
            displayEvents: .init(onAppear: {}, onDisappear: {}))
    }

    static func makeCommentDetail(
        uuid: String = "comment-uuid",
        text: String? = "Detail text",
        aggregatedInfo: AggregatedInfo = .init(reactions: [], childCount: 0, viewCount: 0, pollResult: nil),
        canBeBlockedByUser: Bool = false
    ) -> CommentDetailViewModel.CommentDetail {
        let author = Author(
            profile: MinimalProfile(
                uuid: "profile-id",
                nickname: "Bobby",
                avatarUrl: URL(string: "https://example.com/a.jpg")!,
                gamificationLevel: 1),
            gamificationLevel: nil)

        let translatable: TranslatableText? = text.map {
            TranslatableText(originalText: $0, originalLanguage: nil)
        }

        return CommentDetailViewModel.CommentDetail(
            uuid: uuid,
            parentId: "parent-post-id",
            text: translatable,
            image: nil,
            author: author,
            relativeDate: "1h",
            aggregatedInfo: aggregatedInfo,
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: canBeBlockedByUser)
    }
}
