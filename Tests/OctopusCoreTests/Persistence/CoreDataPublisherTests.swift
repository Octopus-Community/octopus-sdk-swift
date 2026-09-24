//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
@preconcurrency import CoreData
import Testing
import Combine
import OctopusDependencyInjection
@testable import OctopusCore

@Suite(.serialized)
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

    @Test
    @MainActor
    func testChunkedPublisherWithLotsOfPosts() async throws {
        let context = coreDataStack.saveContext
        let ids = (0..<1200).map { "post-\($0)" }

        // Insert more posts than SQLite's variable limit (999)
        for id in ids {
            let postEntity = PostEntity(context: context)
            postEntity.uuid = id
            postEntity.text = "Test post \(id)"
            postEntity.creationTimestamp = 0
            postEntity.parentId = ""
        }
        try context.save()

        var receivedPosts = [PostEntity]()
        context
            .chunkedPublisher(ids: ids, requestBuilder: { PostEntity.fetchAllByIds(ids: $0) }) { $0 }
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    #expect(Bool(false))
                }
            }, receiveValue: {
                receivedPosts = $0
            })
            .store(in: &storage)

        try await delay()
        #expect(receivedPosts.count == 1200)
    }

    @Test
    func testSaveLandingWhileTheSubscriptionIsStillBeingWiredIsNotLost() async throws {
        let context = coreDataStack.saveContext
        let values = ValuesBox()

        context
            .publisher(request: PostEntity.fetchAll()) { $0.map(\.uuid) }
            .sink { value in
                guard values.append(value) == 1 else { return }
                // The first fetch has read the store, but the publisher has not necessarily started
                // listening for saves yet. Commit a save from another thread while this delivery is
                // still on the stack: whoever wins the race, the saved post is still owed to us.
                context.perform {
                    let postEntity = PostEntity(context: context)
                    postEntity.uuid = "PostID"
                    postEntity.text = "Text"
                    postEntity.creationTimestamp = 0
                    postEntity.parentId = "parentId"
                    try? context.save()
                }
                // Stand-in for the scheduling hiccup that makes this race lose on a loaded machine.
                Thread.sleep(forTimeInterval: 0.3)
            }
            .store(in: &storage)

        try await expectWithTimeout(values.last.contains("PostID"))
    }

    @Test
    func testAFailingFetchIsSkippedWithoutEndingTheStreamAndIsRetriedOnTheNextSave() async throws {
        let context = coreDataStack.saveContext
        let fetchShouldFail = Locked(true)
        let values = ValuesBox()
        let completed = Locked(false)

        context
            .publisher(observing: [PostEntity.self]) { [context] () -> [String] in
                guard !fetchShouldFail.value else { throw FetchError.failed }
                return try context.fetch(PostEntity.fetchAll()).map(\.uuid)
            }
            .sink(receiveCompletion: { _ in completed.value = true },
                  receiveValue: { _ = values.append($0) })
            .store(in: &storage)

        try await delay()

        // The first fetch threw: nothing was published, and — the point of the whole thing — the
        // subscription was not completed by it.
        #expect(values.isEmpty)
        #expect(!completed.value)

        fetchShouldFail.value = false
        try await context.performAsync { [context] in
            let postEntity = PostEntity(context: context)
            postEntity.uuid = "PostID"
            postEntity.text = "Text"
            postEntity.creationTimestamp = 0
            postEntity.parentId = "parentId"
            try context.save()
        }

        try await expectWithTimeout(values.last.contains("PostID"))
        #expect(!completed.value)
    }

    @Test
    func testAFailingSaveDrivenFetchIsSkippedAndTheNextOneStillArrives() async throws {
        let context = coreDataStack.saveContext
        let fetchShouldFail = Locked(false)
        let values = ValuesBox()
        let completed = Locked(false)

        context
            .publisher(observing: [PostEntity.self]) { [context] () -> [String] in
                guard !fetchShouldFail.value else { throw FetchError.failed }
                return try context.fetch(PostEntity.fetchAll()).map(\.uuid)
            }
            .sink(receiveCompletion: { _ in completed.value = true },
                  receiveValue: { _ = values.append($0) })
            .store(in: &storage)

        try await expectWithTimeout(values.count == 1)

        // A save whose fetch throws: skipped, so no value — but the stream has to survive it.
        fetchShouldFail.value = true
        try await context.performAsync { [context] in
            let postEntity = PostEntity(context: context)
            postEntity.uuid = "PostID"
            postEntity.text = "Text"
            postEntity.creationTimestamp = 0
            postEntity.parentId = "parentId"
            try context.save()
        }

        try await delay()
        #expect(values.count == 1)
        #expect(!completed.value)

        // The next save is fetched again and lands, post included.
        fetchShouldFail.value = false
        try await context.performAsync { [context] in
            let postEntity = PostEntity(context: context)
            postEntity.uuid = "OtherPostID"
            postEntity.text = "Text"
            postEntity.creationTimestamp = 0
            postEntity.parentId = "parentId"
            try context.save()
        }

        try await expectWithTimeout(values.last.contains("OtherPostID"))
        #expect(values.last.contains("PostID"))
        #expect(!completed.value)
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

/// Thread-safe recorder: the publisher delivers on whichever thread saved, the test reads on its own.
private final class ValuesBox: @unchecked Sendable {
    private let lock = NSLock()
    private var values = [[String]]()

    /// Records `value` and returns how many values have been recorded so far.
    func append(_ value: [String]) -> Int {
        lock.lock()
        defer { lock.unlock() }
        values.append(value)
        return values.count
    }

    var last: [String] {
        lock.lock()
        defer { lock.unlock() }
        return values.last ?? []
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return values.count
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return values.isEmpty
    }
}

private enum FetchError: Error {
    case failed
}

/// Thread-safe box, for the flags the fetch closures (called on whichever thread saved) and the test
/// body share.
private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    var value: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storedValue = newValue
        }
    }

    init(_ value: Value) {
        storedValue = value
    }
}
