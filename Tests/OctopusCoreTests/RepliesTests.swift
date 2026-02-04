//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
import SwiftProtobuf
@testable import OctopusCore

class RepliesTests: XCTestCase {
    /// Object that is tested
    private var repliesRepository: RepliesRepository!

    private var repliesDatabase: RepliesDatabase!
    private var mockOctoService: MockOctoService!
    private var storage = [AnyCancellable]()

    override func setUp() {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { _ in Validators(appManagedFields: []) }
        injector.registerMocks(.remoteClient, .authProvider, .networkMonitor, .blockedUserIdsProvider,
                               .configRepository, .appStateMonitor)
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }

        repliesRepository = RepliesRepository(injector: injector)
        repliesDatabase = injector.getInjected(identifiedBy: Injected.repliesDatabase)
        mockOctoService = (injector.getInjected(identifiedBy: Injected.remoteClient).octoService as! MockOctoService)
    }

    func testCreateComment() async throws {
        let sendExpectation = XCTestExpectation(description: "Reply DB updated")

        repliesDatabase.repliesPublisher(ids: ["newReply"])
            .replaceError(with: [])
            .sink { replies in
                guard !replies.isEmpty else { return }
                sendExpectation.fulfill()
            }.store(in: &storage)

        injectPutReply(StorableReply(uuid: "newReply",
                                     text: .init(originalText: "My Comment", originalLanguage: nil, translatedText: nil),
                                     medias: [],
                                     author: .init(uuid: "me", nickname: "Me", avatarUrl: nil, gamificationLevel: nil),
                                     creationDate: Date(), updateDate: Date(),
                                     status: .published, statusReasons: [],
                                     parentId: "commentId",
                                     aggregatedInfo: .empty,
                                     userInteractions: UserInteractions(reaction: nil, pollVoteId: nil)
                                    ))
        let reply = WritableReply(commentId: "commentId", text: "My Reply", imageData: nil)
        try await repliesRepository.send(reply, parentIsTranslated: false)

        await fulfillment(of: [sendExpectation], timeout: 0.5)
    }

    func testDeleteReply() async throws {
        try await repliesDatabase.upsert(replies: [
            StorableReply(uuid: "1",
                          text: .init(originalText: "My Comment", originalLanguage: nil, translatedText: nil),
                          medias: [],
                          author: .init(uuid: "me", nickname: "Me", avatarUrl: nil, gamificationLevel: nil),
                          creationDate: Date(), updateDate: Date(),
                          status: .published, statusReasons: [],
                          parentId: "commentId",
                          aggregatedInfo: .empty,
                          userInteractions: UserInteractions(reaction: nil, pollVoteId: nil))
        ])

        mockOctoService.injectNextDeleteReplyResponse(Com_Octopuscommunity_DeleteReplyResponse())
        _ = try await repliesRepository.deleteReply(replyId: "1")

        try await delay()

        let replies = try await repliesDatabase.getReplies(ids: ["1"])
        XCTAssertTrue(replies.isEmpty)
    }

    func injectPutReply(_ reply: StorableReply) {
        let octoObject = Com_Octopuscommunity_OctoObject.with {
            $0.createdAt = reply.creationDate.timestampMs
            $0.id = reply.uuid
            $0.parentID = reply.parentId
            $0.createdBy = .with {
                $0.profileID = reply.author!.uuid
                $0.nickname = reply.author!.nickname
            }
            $0.content = .with {
                $0.reply = .with {
                    if let text = reply.text {
                        $0.text = text.originalText
                    }
                }
            }
        }

        mockOctoService.injectNextPutReplyResponse(.with {
            $0.result = .success(.with {
                $0.reply = octoObject
            })
        })
    }
}
