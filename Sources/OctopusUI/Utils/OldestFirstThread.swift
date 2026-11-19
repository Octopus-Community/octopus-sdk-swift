//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// A thread listed from its first response, as the post detail screen lists it when it opens on the post itself: the
/// pages loaded from the start of the thread, then, once they reach its end, the newest responses the screen polls.
enum OldestFirstThread {
    /// The responses listed: the pages loaded from the start of the thread, then the newest responses they do not list
    /// yet. Those are added only once the pages reach the end of the thread as the server knows it. Before, responses
    /// not loaded yet separate them from the pages: the end of the thread would show below its start, or alone while
    /// the first page loads, then be pushed away as the pages come in.
    /// - Parameters:
    ///   - oldestFirst: the pages loaded from the start of the thread, `nil` before the first one.
    ///   - reachedEnd: whether those pages reach the end of the thread as the server listed it.
    ///   - newestFirst: the newest responses, newest first.
    /// - Returns: `nil` until the start of the thread is known: no page yet, or none but stored ones that list nothing.
    ///   An empty list is a thread known to be empty, whose newest responses the screen then polls.
    static func listed<Item>(oldestFirst: [Item]?, reachedEnd: Bool, newestFirst: [Item],
                             id: (Item) -> String) -> [Item]? {
        guard let oldestFirst, !oldestFirst.isEmpty || reachedEnd else { return nil }
        guard reachedEnd else { return oldestFirst }
        var listed = oldestFirst
        var listedIds = Set(oldestFirst.map(id))
        for item in newestFirst.reversed() where listedIds.insert(id(item)).inserted {
            listed.append(item)
        }
        return listed
    }
}
