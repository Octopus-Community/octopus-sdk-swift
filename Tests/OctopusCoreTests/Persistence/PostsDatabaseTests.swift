//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusDependencyInjection
@testable import OctopusCore

@Suite
class PostsDatabaseTests {
    let postsDatabase: PostsDatabase

    init() {
        let coreDataStack = try! ModelCoreDataStack(inRam: true)
        let injector = Injector()
        injector.register { _ in coreDataStack }
        postsDatabase = PostsDatabase(injector: injector)
    }

    @Test
    func testDeleteLotsOfPosts() async throws {
        /// Precondition: having lots of posts in the db
        let posts = (0..<10000).map {
            createStorablePost(id: "post-\($0)")
        }
        try await postsDatabase.upsert(posts: posts)

        /// Now test the deletion
        try await postsDatabase.deleteAll(except: posts.prefix(5000).map { $0.uuid })

        let postsInDb = try await postsDatabase.getPosts(ids: posts.map { $0.uuid })
        #expect(postsInDb.count == 5000)
    }

    private func createStorablePost(id: String) -> StorablePost {
        StorablePost(
            uuid: id,
            text: TranslatableText(originalText: "Test post \(id)", originalLanguage: "en"),
            medias: [],
            poll: nil,
            author: nil,
            creationDate: Date(),
            updateDate: Date(),
            status: .published,
            statusReasons: [],
            parentId: "",
            descCommentFeedId: nil,
            ascCommentFeedId: nil,
            bridgeClientObjectId: nil,
            bridgeCatchPhrase: nil,
            bridgeCtaText: nil,
            customActionText: nil,
            customActionTargetLink: nil,
            aggregatedInfo: nil,
            userInteractions: nil
        )
    }
}
