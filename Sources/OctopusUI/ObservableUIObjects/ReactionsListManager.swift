//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore

/// Gives the "who reacted" sheet access to the reactions repository.
///
/// The sheet is opened from deep inside the content views (`PostView`, `ResponseView`), none of which
/// holds an `OctopusSDK`. Rather than threading the SDK down through every one of those signatures, this
/// follows the same convention as the other UI managers: built once by `OctopusHomeScreen` and read from
/// the environment where it is needed.
@MainActor
final class ReactionsListManager: ObservableObject {
    /// Deliberately an *untyped* `throws`, even though everything it can throw is a `ServerCallError`.
    ///
    /// A typed `throws` clause inside a function **type** (unlike one on a function *declaration*, which is
    /// fine) makes the Swift runtime build the function's metadata through
    /// `swift_getExtendedFunctionTypeMetadata`, an entry point that only exists in the iOS 18 runtime. Since
    /// this is a stored property of an `ObservableObject`, the default `objectWillChange` reflects over it to
    /// look for `@Published` wrappers, and on anything older that weakly linked symbol is null: the process
    /// jumps to address 0 as soon as `@EnvironmentObject` or `Compat.StateObject` touches the manager.
    typealias Fetch = (
        _ contentId: String, _ kind: ReactionKind?, _ cursor: String?, _ pageSize: Int
    ) async throws -> ReactionsPage

    private let fetchBlock: Fetch

    /// Designated init. Accepts the fetch directly so previews/tests can serve fixed pages without
    /// requiring a full `OctopusSDK`.
    init(fetch: @escaping Fetch) {
        fetchBlock = fetch
    }

    /// Production convenience.
    convenience init(octopus: OctopusSDK) {
        self.init(fetch: { contentId, kind, cursor, pageSize in
            try await octopus.core.reactionsRepository.fetchReactions(
                contentId: contentId, kind: kind, cursor: cursor, pageSize: pageSize)
        })
    }

    /// Re-types what `Fetch` had to widen to `any Error`: callers keep a typed `throws(ServerCallError)`.
    func fetch(contentId: String, kind: ReactionKind?, cursor: String?, pageSize: Int)
    async throws(ServerCallError) -> ReactionsPage {
        do {
            return try await fetchBlock(contentId, kind, cursor, pageSize)
        } catch let error as ServerCallError {
            throw error
        } catch {
            throw .other(error)
        }
    }

    /// Preview factory — serves one fixed page and never pages.
    static func forPreviews(reactions: [ProfileReaction] = []) -> ReactionsListManager {
        ReactionsListManager(fetch: { _, _, _, _ in
            ReactionsPage(reactions: reactions, nextCursor: nil)
        })
    }
}
