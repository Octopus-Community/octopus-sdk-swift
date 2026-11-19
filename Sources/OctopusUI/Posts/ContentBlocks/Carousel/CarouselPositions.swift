//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import SwiftUI

/// The page each image carousel shows, per post.
///
/// A lazy feed destroys the views of the rows that leave the screen, and their `@State` with them. Keeping the
/// position outside the view lets a carousel scrolled back into view (or the same post shown on another screen)
/// open on the photo the user left it on.
///
/// The positions are not published: a carousel reads its position when it is created and writes it back when the
/// user swipes, so a swipe in one post does not re-render the carousels of the other posts. A carousel that stays
/// alive while the same post moves elsewhere (the feed under a post detail) follows `changes` for its own post.
///
/// The entry screen (`OctopusHomeScreen`) owns one, like its `VideoManager`: the positions
/// go away with the screen, instead of outliving the session, a community switch or the SDK instance.
@MainActor
final class CarouselPositions: ObservableObject {
    private var indexes: [String: Int] = [:]

    /// Each change of the position of a post, sent once per actual change.
    let changes = PassthroughSubject<(postId: String, index: Int), Never>()

    nonisolated init() {}

    /// The index of the page shown by the carousel of a post, 0 when it has never been moved.
    func index(for postId: String) -> Int {
        indexes[postId] ?? 0
    }

    /// Records the index of the page shown by the carousel of a post.
    func set(_ index: Int, for postId: String) {
        guard self.index(for: postId) != index else { return }
        indexes[postId] = index
        changes.send((postId: postId, index: index))
    }
}

private struct CarouselPositionsKey: EnvironmentKey {
    /// A new instance on each read: outside of the entry screens (previews), positions are simply not kept.
    static var defaultValue: CarouselPositions { CarouselPositions() }
}

extension EnvironmentValues {
    /// Where the image carousels keep the page they show.
    var carouselPositions: CarouselPositions {
        get { self[CarouselPositionsKey.self] }
        set { self[CarouselPositionsKey.self] = newValue }
    }
}
