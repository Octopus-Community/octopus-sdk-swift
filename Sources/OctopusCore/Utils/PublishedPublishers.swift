//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine

/// Creates the publishers of `@Published` values ahead of time, so that their creation never races a write.
///
/// Combine does not document it, but its current `@Published` only creates its publisher on the first `$value`
/// access, switching its storage from the bare value to that publisher at that moment (seen in crash stacks, and
/// pinned by `PublishedPublishersTests`). When that first access happens on one thread while the value is written on
/// another (a sink delivering on the main queue, a task), both race on that storage switch: a data race that can
/// detach the publisher, so its subscribers never see a change again, or crash in the `@Published` setter. Once the
/// publisher exists, writes go through it and later `$value` accesses no longer change the storage, so creating it in
/// `init`, while nothing else can reach the object yet, closes the window of that switch.
enum PublishedPublishers {
    /// Call it in `init` with every `$value` of the object, before anything can write them.
    ///
    /// The work is done by evaluating the arguments: the body has nothing left to do. A new class calling it belongs
    /// in `PublishedPublishersTests.Subject`, which lists them by hand.
    static func create(_ publishers: any PublishedPublisher...) { }
}

/// The publisher of a `@Published` value, the only thing `PublishedPublishers.create` accepts: passing the value itself
/// (`value` instead of `$value`) would compile, create nothing, and go unnoticed.
protocol PublishedPublisher { }

extension Published.Publisher: PublishedPublisher { }
