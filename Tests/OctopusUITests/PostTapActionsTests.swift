//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import Testing
import OctopusCore
@testable import OctopusUI

/// The post image and group name taps for every combination of options and context (ported from Android's
/// `PostTapActionsTest` and `PostCardTapTest`).
@MainActor
struct PostTapActionsTests {
    private final class Calls {
        var values: [String] = []
    }

    private static func options(image: Bool, group: Bool) -> ContentOptions.PostOptions {
        .init(enablePictures: true, enablePolls: true, imageTapOpensPost: image, groupNameTapOpensGroup: group)
    }

    private static let allOptions: [ContentOptions.PostOptions?] = [
        nil,
        ContentOptions.allEnabled.post,
        options(image: true, group: false),
        options(image: false, group: true),
        options(image: true, group: true),
    ]

    // MARK: - Image tap

    @Test func feedImageTapOpensThePostOnlyWhenEnabledAndTheCardOpensTheDetail() {
        for options in Self.allOptions {
            for cardTapOpensDetail in [false, true] {
                for displayGroupName in [false, true] {
                    let calls = Calls()
                    let context = PostViewContext.summary(onCardTap: { calls.values.append("post") },
                                                          displayGroupName: displayGroupName)
                    let override = PostTapActions.imageTapOverride(context: context, options: options,
                                                                   cardTapOpensDetail: cardTapOpensDetail)
                    override?()
                    let opensPost = cardTapOpensDetail && options?.imageTapOpensPost == true
                    // `nil` keeps the fullscreen viewer.
                    #expect((override != nil) == opensPost)
                    #expect(calls.values == (opensPost ? ["post"] : []))
                }
            }
        }
    }

    @Test func detailImageTapAlwaysKeepsFullscreen() {
        for options in Self.allOptions {
            #expect(PostTapActions.imageTapOverride(context: .detail, options: options,
                                                    cardTapOpensDetail: true) == nil)
        }
    }

    // MARK: - Group name tap

    @Test func unconfiguredGroupNameKeepsTheCardActionInFeedsAndIsInertInDetail() {
        for options in [nil, ContentOptions.allEnabled.post, Self.options(image: true, group: false)] {
            let calls = Calls()
            let summary = PostViewContext.summary(onCardTap: { calls.values.append("post") }, displayGroupName: true)
            PostTapActions.groupNameTapAction(context: summary, options: options,
                                              openGroup: { calls.values.append("group") })?()
            #expect(calls.values == ["post"])
            #expect(PostTapActions.groupNameTapAction(context: .detail, options: options,
                                                      openGroup: { calls.values.append("group") }) == nil)
        }
    }

    @Test func enabledGroupNameOpensTheGroupInFeedsAndDetailIndependentlyOfImageTaps() {
        for image in [false, true] {
            let calls = Calls()
            let options = Self.options(image: image, group: true)
            let summary = PostViewContext.summary(onCardTap: { calls.values.append("post") }, displayGroupName: true)
            PostTapActions.groupNameTapAction(context: summary, options: options,
                                              openGroup: { calls.values.append("group") })?()
            PostTapActions.groupNameTapAction(context: .detail, options: options,
                                              openGroup: { calls.values.append("group") })?()
            #expect(calls.values == ["group", "group"])
        }
    }

    @Test func enabledGroupNameWithoutGroupIdKeepsTheExistingBehaviour() {
        let calls = Calls()
        let options = Self.options(image: false, group: true)
        let summary = PostViewContext.summary(onCardTap: { calls.values.append("post") }, displayGroupName: true)
        PostTapActions.groupNameTapAction(context: summary, options: options, openGroup: nil)?()
        #expect(calls.values == ["post"])
        #expect(PostTapActions.groupNameTapAction(context: .detail, options: options, openGroup: nil) == nil)
    }

    // MARK: - DisplayConfigManager: options and group access

    @Test func postOptionsFollowTheCommunityConfig() {
        let subject = CurrentValueSubject<ContentOptions.PostOptions, Never>(ContentOptions.allEnabled.post)
        let manager = DisplayConfigManager(poweredByPublisher: Just(.normal).eraseToAnyPublisher(),
                                           postOptionsPublisher: subject.eraseToAnyPublisher())
        #expect(manager.postOptions == ContentOptions.allEnabled.post)
        subject.send(Self.options(image: true, group: true))
        #expect(manager.postOptions == Self.options(image: true, group: true))
    }

    @Test func groupWithoutAccessCallsTheAccessDeniedCallbackLikeTheGroupsList() {
        let calls = Calls()
        let manager = makeManager(canAccess: false, calls: calls)
        manager.openGroupFromPost(groupId: "group-1") { calls.values.append("open \($0)") }
        #expect(calls.values == ["denied group-1"])
    }

    @Test func accessibleGroupOpens() {
        let calls = Calls()
        let manager = makeManager(canAccess: true, calls: calls)
        manager.openGroupFromPost(groupId: "group-1") { calls.values.append("open \($0)") }
        #expect(calls.values == ["open group-1"])
    }

    @Test func unknownGroupOpensItsPage() {
        let calls = Calls()
        let manager = makeManager(canAccess: nil, calls: calls)
        manager.openGroupFromPost(groupId: "group-1") { calls.values.append("open \($0)") }
        #expect(calls.values == ["open group-1"])
    }

    private func makeManager(canAccess: Bool?, calls: Calls) -> DisplayConfigManager {
        DisplayConfigManager(
            poweredByPublisher: Just(.normal).eraseToAnyPublisher(),
            canAccessGroup: { _ in canAccess },
            onGroupAccessDenied: { calls.values.append("denied \($0)") })
    }
}
