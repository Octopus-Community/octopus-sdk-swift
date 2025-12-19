//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Combine
import OctopusDependencyInjection
@testable import OctopusCore

@Suite
class CoreDataPublisherTests {
    let coreDataStack = try! ModelCoreDataStack(inRam: true)
    private var storage = [AnyCancellable]()

    @Test
    @MainActor // we use viewContext so it needs to be on the main thread
    func testPublisher() async throws {
        let context = coreDataStack.saveContext
        var posts: [PostEntity]?
        context
            .publisher(request: PostEntity.fetchAll()) { $0 }
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    #expect(Bool(false))
                }
            }, receiveValue: {
                posts = $0
            })
            .store(in: &storage)

        try await delay()
        #expect(posts == [])

        let postEntity = PostEntity(context: context)
        postEntity.uuid = "PostID"
        postEntity.text = "Text"
        postEntity.authorId = "AuthorId"
        postEntity.authorNickname = "Author"
        postEntity.creationTimestamp = 0
        postEntity.parentId = "parentId"
        try context.save()

        try await delay()

        let post = try #require(posts?.first)
        #expect(post.uuid == "PostID")
    }

    @Test
    @MainActor // we use viewContext so it needs to be on the main thread
    func testPublisherWithRelatedEntity() async throws {
        let context = coreDataStack.saveContext
        var posts: [PostEntity]?

        let postEntity = PostEntity(context: context)
        postEntity.uuid = "PostID"
        postEntity.text = "Text"
        let profile = MinimalProfileEntity(context: context)
        profile.profileId = "AuthorId"
        profile.nickname = "Author"
        postEntity.author = profile
        postEntity.creationTimestamp = 0
        postEntity.parentId = "parentId"
        try context.save()

        context
            .publisher(request: PostEntity.fetchAll()) { $0 }
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    #expect(Bool(false))
                }
            }, receiveValue: {
                posts = $0
            })
            .store(in: &storage)
        try await delay()

        let post = try #require(posts?.first)
        #expect(post.uuid == "PostID")
        #expect(post.author?.nickname == "Author")

        profile.nickname = "New Author"
        try context.save()

        try await delay()

        let newPost = try #require(posts?.first)
        #expect(newPost.uuid == "PostID")
        #expect(newPost.author?.nickname == "New Author")
    }

//    @Test
//    func testPublisherWithBackgroundChanges() async throws {
//        let context = coreDataStack.persistentContainer.viewContext
//        let backgroundContext = coreDataStack.persistentContainer.newBackgroundContext()
//        var posts: [PostEntity]?
//        context
//            .publisher(request: PostEntity.fetchAll(), saveContext: backgroundContext)
//            .sink(receiveCompletion: { completion in
//                if case .failure = completion {
//                    #expect(Bool(false))
//                }
//            }, receiveValue: {
//                print("Post received: \($0)")
//                posts = $0
//            })
//            .store(in: &storage)
//
//        try await delay()
//        #expect(posts == [])
//
//        print("Begin !!!")
//
//        try await backgroundContext.performAsync { [backgroundContext] in
//            print("Save begin")
//            let postEntity = PostEntity(context: context)
//            postEntity.uuid = "PostID"
//            postEntity.headline = "Headline"
//            postEntity.authorId = "AuthorId"
//            postEntity.authorNickname = "Author"
//            postEntity.creationTimestamp = 0
//            postEntity.parentId = "parentId"
//            try backgroundContext.save()
//            print("Save done")
//        }
//
//        print("Done")
//
//        try await delay()
//
//        let post = try #require(posts?.first)
//        #expect(post.uuid == "PostID")
//    }
}
