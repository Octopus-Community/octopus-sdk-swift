//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import DependencyInjection

extension Injected {
    static let commentFeedsStore = Injector.InjectedIdentifier<CommentFeedsStore>()
    static let postFeedsStore = Injector.InjectedIdentifier<PostFeedsStore>()
}

class CommentFeedsStore: InjectableObject {
    static let injectedIdentifier = Injected.commentFeedsStore

    private let commentsFeedManager: FeedManager<Comment>
    private var feeds = NSMapTable<NSString, Feed<Comment>>(keyOptions: .strongMemory, valueOptions: .weakMemory)

    init(injector: Injector) {
        commentsFeedManager = CommentsFeedManager.factory(injector: injector)
    }

    func getOrCreate(feedId: String) -> Feed<Comment> {
        if let feed = feeds.object(forKey: feedId as NSString) {
            return feed
        } else {
            let feed = Feed(id: feedId, feedManager: commentsFeedManager)
            feeds.setObject(feed, forKey: feedId as NSString)
            return feed
        }
    }
}

class PostFeedsStore: InjectableObject {
    static let injectedIdentifier = Injected.postFeedsStore

    private let postsFeedManager: FeedManager<Post>
    private var feeds = NSMapTable<NSString, Feed<Post>>(keyOptions: .strongMemory, valueOptions: .weakMemory)

    init(injector: Injector) {
        postsFeedManager = PostsFeedManager.factory(injector: injector)
    }

    func getOrCreate(feedId: String) -> Feed<Post> {
        if let feed = feeds.object(forKey: feedId as NSString) {
            return feed
        } else {
            let feed = Feed(id: feedId, feedManager: postsFeedManager)
            feeds.setObject(feed, forKey: feedId as NSString)
            return feed
        }
    }
}
