//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import OctopusCore

/// Tests for the `.groupSelection` context filter applied in `GroupListViewModel`.
///
/// The ViewModel itself requires a full OctopusSDK instance, so the filtering predicate
/// is tested as a pure helper below (mirroring the pattern in `CreatePostViewModelTests`).
struct GroupListViewModelTests {

    // MARK: - .groupSelection filter

    @Test func groupSelectionKeepsTopicWhenCanCreateChildrenTrue() {
        let topics: [(id: String, permissions: UserPermissions)] = [
            ("open", .init(canAccess: true, canCreateChildren: true))
        ]
        let result = topicsForGroupSelection(topics)
        #expect(result == ["open"])
    }

    @Test func groupSelectionDropsTopicWhenCanCreateChildrenFalse() {
        let topics: [(id: String, permissions: UserPermissions)] = [
            ("noCreate", .init(canAccess: true, canCreateChildren: false))
        ]
        let result = topicsForGroupSelection(topics)
        #expect(result.isEmpty)
    }

    /// Inaccessible topics remain in the picker so the tap handler can dispatch the
    /// access-denied callback. Only `canCreateChildren` controls visibility.
    @Test func groupSelectionKeepsTopicWhenCanAccessFalseButCanCreateChildrenTrue() {
        let topics: [(id: String, permissions: UserPermissions)] = [
            ("noAccess", .init(canAccess: false, canCreateChildren: true))
        ]
        let result = topicsForGroupSelection(topics)
        #expect(result == ["noAccess"])
    }

    @Test func groupSelectionDropsTopicWhenBothFalse() {
        let topics: [(id: String, permissions: UserPermissions)] = [
            ("both", .init(canAccess: false, canCreateChildren: false))
        ]
        let result = topicsForGroupSelection(topics)
        #expect(result.isEmpty)
    }

    @Test func groupSelectionKeepsAllWritableTopicsRegardlessOfAccess() {
        let topics: [(id: String, permissions: UserPermissions)] = [
            ("open", .init(canAccess: true, canCreateChildren: true)),
            ("noAccess", .init(canAccess: false, canCreateChildren: true)),
            ("noCreate", .init(canAccess: true, canCreateChildren: false)),
            ("both", .init(canAccess: false, canCreateChildren: false))
        ]
        let result = topicsForGroupSelection(topics)
        #expect(result == ["open", "noAccess"])
    }

    @Test func displayFeedKeepsAllTopics() {
        let topics: [(id: String, permissions: UserPermissions)] = [
            ("open", .init(canAccess: true, canCreateChildren: true)),
            ("noCreate", .init(canAccess: true, canCreateChildren: false)),
            ("noAccess", .init(canAccess: false, canCreateChildren: true))
        ]
        let result = topicsForDisplayFeed(topics)
        #expect(result == ["open", "noCreate", "noAccess"])
    }
}

// MARK: - Pure predicate helpers (mirror the filter in GroupListViewModel)

extension GroupListViewModelTests {
    private func topicsForGroupSelection(_ topics: [(id: String, permissions: UserPermissions)]) -> [String] {
        topics
            .filter { $0.permissions.canCreateChildren }
            .map(\.id)
    }

    private func topicsForDisplayFeed(_ topics: [(id: String, permissions: UserPermissions)]) -> [String] {
        topics.map(\.id)
    }
}
