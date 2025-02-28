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

class CommentsTests: XCTestCase {
    /// Object that is tested
    private var commentsRepository: CommentsRepository!

    private var commentsDatabase: CommentsDatabase!
    private var connectionRepository: ConnectionRepository!
    private var mockOctoService: MockOctoService!
    private var storage = [AnyCancellable]()

    override func setUp() {
        let injector = Injector()
        injector.register { _ in try! CoreDataStack(inRam: true) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { _ in Validators(appManagedFields: []) }
        injector.registerMocks(.remoteClient, .authProvider, .networkMonitor)

        commentsRepository = CommentsRepository(injector: injector)
        commentsDatabase = injector.getInjected(identifiedBy: Injected.commentsDatabase)
        mockOctoService = (injector.getInjected(identifiedBy: Injected.remoteClient).octoService as! MockOctoService)
    }

    func testCreateComment() async throws {
        let sendExpectation = XCTestExpectation(description: "Comment DB updated")

        commentsDatabase.commentsPublisher(ids: ["newComment"])
            .replaceError(with: [])
            .sink { comments in
                guard !comments.isEmpty else { return }
                sendExpectation.fulfill()
            }.store(in: &storage)

        injectPutComment(Comment(uuid: "newComment", text: "My Comment", medias: [],
                                 author: .init(uuid: "me", nickname: "Me", avatarUrl: nil),
                                 creationDate: Date(), updateDate: Date(),
                                 parentId: "postId",
                                 aggregatedInfo: .empty,
                                 userInteractions: UserInteractions(userLikeId: nil),
                                 innerStatus: .published, innerStatusReasons: []))
        let comment = WritableComment(postId: "postId", text: "My Comment", imageData: nil)
        try await commentsRepository.send(comment)

        await fulfillment(of: [sendExpectation], timeout: 0.5)
    }

    func testDeleteComment() async throws {
        try await commentsDatabase.upsert(comments: [
            Comment(uuid: "1", text: "My Comment", medias: [],
                    author: .init(uuid: "me", nickname: "Me", avatarUrl: nil),
                    creationDate: Date(), updateDate: Date(),
                    parentId: "postId",
                    aggregatedInfo: .empty,
                    userInteractions: UserInteractions(userLikeId: nil),
                    innerStatus: .published, innerStatusReasons: [])
        ])

        mockOctoService.injectNextDeleteCommentResponse(Com_Octopuscommunity_DeleteCommentResponse())
        _ = try await commentsRepository.deleteComment(commentId: "1")

        try await delay()

        let comments = try await commentsDatabase.getComments(ids: ["1"])
        XCTAssertTrue(comments.isEmpty)
    }

    func injectPutComment(_ comment: Comment) {
        let octoObject = Com_Octopuscommunity_OctoObject.with {
            $0.createdAt = comment.creationDate.timestampMs
            $0.id = comment.uuid
            $0.parentID = comment.parentId
            $0.createdBy = .with {
                $0.profileID = comment.author!.uuid
                $0.nickname = comment.author!.nickname
            }
            $0.content = .with {
                $0.comment = .with {
                    if let text = comment.text {
                        $0.text = text
                    }
                }
            }
        }

        mockOctoService.injectNextPutCommentResponse(.with {
            $0.result = .success(.with {
                $0.comment = octoObject
            })
        })
    }
}
