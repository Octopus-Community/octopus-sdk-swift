//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection
import Testing
@testable import OctopusUI
@testable import OctopusCore

struct EditPreviewDefaultAvatarTests {
    static let own = DefaultAvatar.color(backgroundHex: "#3366CC", initialsHex: "#FFFFFF")
    static let ifRemoved = DefaultAvatar.image(url: URL(string: "https://cdn.example.com/a1b2.jpg")!)

    // One Core Data stack per test instance (Swift Testing creates a fresh struct per @Test).
    private let postFeedsStore: PostFeedsStore = {
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
        return injector.getInjected(identifiedBy: Injected.postFeedsStore)
    }()

    private func profile(pictureUrl: URL?, defaultAvatar: DefaultAvatar?,
                         defaultAvatarIfPictureRemoved: DefaultAvatar?) -> CurrentUserProfile {
        CurrentUserProfile(
            storableProfile: StorableCurrentUserProfile(
                id: "p1", userId: "u1", nickname: "Zoé", originalNickname: nil, email: nil, bio: nil,
                pictureUrl: pictureUrl, tags: [], totalMessages: nil, accountCreationDate: nil,
                gamificationLevel: nil, gamificationScore: nil, hasSeenOnboarding: true, hasAcceptedCgu: true,
                hasConfirmedNickname: true, hasConfirmedBio: true, hasConfirmedPicture: true, isGuest: false,
                notificationBadgeCount: nil, descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: [],
                defaultAvatar: defaultAvatar, defaultAvatarIfPictureRemoved: defaultAvatarIfPictureRemoved),
            gamificationLevels: [], postFeedsStore: postFeedsStore)
    }

    @Test func withAPictureThePreviewIsWhatRemovingItGives() {
        let profile = profile(pictureUrl: URL(string: "https://cdn.example.com/own.jpg"), defaultAvatar: nil,
                              defaultAvatarIfPictureRemoved: Self.ifRemoved)
        #expect(profile.editPreviewDefaultAvatar == Self.ifRemoved)
    }

    @Test func withoutPictureThePreviewIsTheDefaultTheMemberHas() {
        let profile = profile(pictureUrl: nil, defaultAvatar: Self.own, defaultAvatarIfPictureRemoved: nil)
        #expect(profile.editPreviewDefaultAvatar == Self.own)
    }

    @Test func withNeitherThereIsNoCommunityAvatar() {
        let profile = profile(pictureUrl: nil, defaultAvatar: nil, defaultAvatarIfPictureRemoved: nil)
        #expect(profile.editPreviewDefaultAvatar == nil)
    }
}
