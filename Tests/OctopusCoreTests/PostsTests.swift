//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import DependencyInjection
import RemoteClient
import GrpcModels
import SwiftProtobuf
@testable import OctopusCore

class PostsTests: XCTestCase {
    /// Object that is tested
    private var postsRepository: PostsRepository!

    private var postsDatabase: PostsDatabase!
    private var mockOctoService: MockOctoService!
    private var blockedUserIdsProvider: MockBlockedUserIdsProvider!
    private var storage = [AnyCancellable]()

    override func setUp() {
        let injector = Injector()
        injector.register { _ in try! CoreDataStack(inRam: true) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { _ in Validators(appManagedFields: []) }
        injector.registerMocks(.remoteClient, .authProvider, .networkMonitor, .blockedUserIdsProvider)

        postsRepository = PostsRepository(injector: injector)
        postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        mockOctoService = (injector.getInjected(identifiedBy: Injected.remoteClient).octoService as! MockOctoService)
        blockedUserIdsProvider = (injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider) as! MockBlockedUserIdsProvider)
    }

    func testCreatePost() async throws {
        let sendExpectation = XCTestExpectation(description: "Comment DB updated")

        postsDatabase.postPublisher(uuid: "newPost")
            .replaceError(with: nil)
            .sink { post in
                if post != nil {
                    sendExpectation.fulfill()
                }
            }.store(in: &storage)

        injectPutPost(StorablePost(
            uuid: "newPost", text: "My Post", medias: [],
            author: .init(uuid: "me", nickname: "Me", avatarUrl: nil), creationDate: Date(), updateDate: Date(),
            status: .published, statusReasons: [],
            parentId: "topicId",
            descCommentFeedId: nil, ascCommentFeedId: nil, aggregatedInfo: nil, userLikeId: nil))
        let post = WritablePost(topicId: "topicId", text: "My Post", imageData: nil)
        try await postsRepository.send(post)

        await fulfillment(of: [sendExpectation], timeout: 0.5)
    }

    func testGetLocalAndRemotePost() async throws {
        let localExpectation = XCTestExpectation(description: "DB updated")

        postsRepository.getPost(uuid: "1")
            .replaceError(with: nil)
            .sink { post in
                if post != nil {
                    localExpectation.fulfill()
                }
            }.store(in: &storage)

        injectGetPost(
            .init(uuid: "1", text: "First Post", medias: [],
                  author: .init(uuid: "me", nickname: "Me", avatarUrl: nil),
                  creationDate: Date(), updateDate: Date(),
                  status: .published, statusReasons: [],
                  parentId: "Sport",
                  descCommentFeedId: "", ascCommentFeedId: "", aggregatedInfo: nil, userLikeId: nil))
        _ = try await postsRepository.fetchPost(uuid: "1")

        await fulfillment(of: [localExpectation], timeout: 0.5)
    }

    func testGetPostIsFilteredOutIfAuthorIsBlocked() async throws {
        // precondition: a post with an author is in the db
        try await postsDatabase.upsert(posts: [
            .init(uuid: "1", text: "First Post", medias: [],
                  author: .init(uuid: "authorId", nickname: "Nick", avatarUrl: nil),
                  creationDate: Date(), updateDate: Date(),
                  status: .published, statusReasons: [],
                  parentId: "Sport",
                  descCommentFeedId: "", ascCommentFeedId: "", aggregatedInfo: nil, userLikeId: nil)
        ])

        let postPresentExpectation = XCTestExpectation(description: "Post is present")

        postsRepository.getPost(uuid: "1")
            .replaceError(with: nil)
            .sink { post in
                if post != nil {
                    postPresentExpectation.fulfill()
                }
            }.store(in: &storage)

        await fulfillment(of: [postPresentExpectation], timeout: 0.5)

        // mock the fact that the author is now blocked
        blockedUserIdsProvider.mockBlockedUserIds(["authorId"])

        let postFilteredOutExpectation = XCTestExpectation(description: "Post is filtered out")

        postsRepository.getPost(uuid: "1")
            .replaceError(with: nil)
            .sink { post in
                if post == nil {
                    postFilteredOutExpectation.fulfill()
                }
            }.store(in: &storage)

        await fulfillment(of: [postFilteredOutExpectation], timeout: 0.5)
    }

    func testDeletePost() async throws {
        try await postsDatabase.upsert(posts: [
            .init(uuid: "1", text: "First Post", medias: [],
                  author: .init(uuid: "me", nickname: "Me", avatarUrl: nil),
                  creationDate: Date(), updateDate: Date(),
                  status: .published, statusReasons: [],
                  parentId: "Sport",
                  descCommentFeedId: "", ascCommentFeedId: "", aggregatedInfo: nil, userLikeId: nil)
        ])

        let localExpectation = XCTestExpectation(description: "DB updated")

        postsRepository.getPost(uuid: "1")
            .replaceError(with: nil)
            .sink { post in
                if post == nil {
                    localExpectation.fulfill()
                }
            }.store(in: &storage)

        mockOctoService.injectNextDeletePostResponse(Com_Octopuscommunity_DeletePostResponse())
        _ = try await postsRepository.deletePost(postId: "1")

        await fulfillment(of: [localExpectation], timeout: 0.5)
    }

    func injectGetPost(_ item: StorablePost) {
        let post = octoPost(from: item)

        let aggregate: Com_Octopuscommunity_Aggregate?
        if let aggregatedInfo = item.aggregatedInfo {
            aggregate = .with {
                $0.childrenCount = UInt32(aggregatedInfo.childCount)
                $0.likeCount = UInt32(aggregatedInfo.likeCount)
                $0.viewCount = UInt32(aggregatedInfo.viewCount)
            }
        } else {
            aggregate = nil
        }

        let requesterCtx = Com_Octopuscommunity_RequesterCtx.with {
            if let userLikeId = item.userLikeId {
                $0.likeID = userLikeId
            }
        }


        mockOctoService.injectNextGetResponse(.with {
            $0.octoObject = post
            if let aggregate {
                $0.aggregate = aggregate
            }
            $0.requesterCtx = requesterCtx
        })
    }

    func injectPutPost(_ post: StorablePost) {
        let octoObject = octoPost(from: post)

        mockOctoService.injectNextPutPostResponse(.with {
            $0.result = .success(.with {
                $0.post = octoObject
            })
        })
    }

    private func octoPost(from item: StorablePost) -> Com_Octopuscommunity_OctoObject {
        Com_Octopuscommunity_OctoObject.with {
            $0.createdAt = item.creationDate.timestampMs
            $0.id = item.uuid
            $0.parentID = item.parentId
            $0.createdBy = .with {
                $0.profileID = item.author!.uuid
                $0.nickname = item.author!.nickname
            }
            $0.content = .with {
                $0.post = .with {
                    $0.text = item.text
                    $0.media = .with {
                        $0.images = [
                            .with {
                                $0.file = .url("https://test.com/image.jpg")
                                $0.width = 100
                                $0.height = 100
                            }
                        ]
                    }
                }
            }
        }
    }
}
