//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import Foundation
import OctopusDependencyInjection
@testable import OctopusUI
@testable import OctopusCore

/// Unit tests for `GroupList.init(from:)` — the pure builder that turns a
/// `[OctopusCore.Topic]` into the SDK's internal Topics-nav block structure.
///
/// Behavior under test (OCT-1392):
/// 1. Topics with no client section land in a single `.noSectionGroups` block at the top,
///    in their incoming array order.
/// 2. Client sections follow, sorted by `Section.position` ascending, each containing
///    its topics in their incoming array order.
/// 3. Follow status and essentiality (`canChangeFollowStatus`) have zero impact on ordering.
@Suite
struct GroupListBuilderTests {

    // MARK: - Fixtures

    private static func makePostFeedsStore() -> PostFeedsStore {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.registerMocks(.remoteClient, .networkMonitor, .authProvider, .blockedUserIdsProvider)
        return injector.getInjected(identifiedBy: Injected.postFeedsStore)
    }

    // One Core Data stack per test instance (Swift Testing creates a fresh struct per @Test).
    private let postFeedsStore: PostFeedsStore = Self.makePostFeedsStore()

    /// Builds a `Topic` with the minimal fields the builder reads. The other fields are
    /// stubbed with neutral defaults — they are not part of the ordering contract.
    private func topic(
        uuid: String,
        sections: [StorableSection] = [],
        isFollowed: Bool = false,
        canChangeFollowStatus: Bool = true
    ) -> OctopusCore.Topic {
        let followStatus: StorableFollowStatus = isFollowed
            ? (canChangeFollowStatus ? .followed : .forceFollowed)
            : (canChangeFollowStatus ? .notFollowed : .forceNotFollowed)
        let storable = StorableTopic(
            uuid: uuid,
            name: uuid,
            description: "",
            followStatus: followStatus,
            sections: sections,
            feedId: "feed-\(uuid)"
        )
        return Topic(from: storable, postFeedsStore: postFeedsStore)
    }

    private func section(uuid: String, name: String, position: Int) -> StorableSection {
        StorableSection(uuid: uuid, name: name, position: position)
    }

    // MARK: - Cases

    @Test func onlyNoSectionTopicsProducesSingleBlockInInputOrder() {
        let topics = [
            topic(uuid: "a"),
            topic(uuid: "b"),
            topic(uuid: "c")
        ]
        let list = GroupList(from: topics)

        #expect(list.sections == [.noSectionGroups])
        #expect(list.groupsBySection[.noSectionGroups]?.map(\.id) == ["a", "b", "c"])
    }

    @Test func emptyInputProducesEmptyOutput() {
        let list = GroupList(from: [])

        #expect(list.sections.isEmpty)
        #expect(list.groupsBySection.isEmpty)
    }

    @Test func onlySectionedTopicsProducesNoNoSectionBlock() {
        let s1 = section(uuid: "s1", name: "Sports", position: 0)
        let s2 = section(uuid: "s2", name: "Cooking", position: 1)
        let topics = [
            topic(uuid: "a", sections: [s1]),
            topic(uuid: "b", sections: [s2]),
            topic(uuid: "c", sections: [s1])
        ]
        let list = GroupList(from: topics)

        #expect(list.sections == [
            .clientSection(name: "Sports"),
            .clientSection(name: "Cooking")
        ])
        #expect(list.groupsBySection[.clientSection(name: "Sports")]?.map(\.id) == ["a", "c"])
        #expect(list.groupsBySection[.clientSection(name: "Cooking")]?.map(\.id) == ["b"])
        #expect(list.groupsBySection[.noSectionGroups] == nil)
    }

    @Test func mixedInputPutsNoSectionBlockFirstThenClientSections() {
        let sports = section(uuid: "s1", name: "Sports", position: 0)
        let topics = [
            topic(uuid: "a"),
            topic(uuid: "b", sections: [sports]),
            topic(uuid: "c")
        ]
        let list = GroupList(from: topics)

        #expect(list.sections == [
            .noSectionGroups,
            .clientSection(name: "Sports")
        ])
        #expect(list.groupsBySection[.noSectionGroups]?.map(\.id) == ["a", "c"])
        #expect(list.groupsBySection[.clientSection(name: "Sports")]?.map(\.id) == ["b"])
    }

    @Test func clientSectionsAreSortedByPositionAscending() {
        let s2 = section(uuid: "s2", name: "Two", position: 2)
        let s0 = section(uuid: "s0", name: "Zero", position: 0)
        let s1 = section(uuid: "s1", name: "One", position: 1)
        let topics = [
            topic(uuid: "x", sections: [s2]),
            topic(uuid: "y", sections: [s0]),
            topic(uuid: "z", sections: [s1])
        ]
        let list = GroupList(from: topics)

        #expect(list.sections == [
            .clientSection(name: "Zero"),
            .clientSection(name: "One"),
            .clientSection(name: "Two")
        ])
    }

    @Test func topicBelongingToTwoClientSectionsAppearsInEach() {
        let s0 = section(uuid: "s0", name: "Sports", position: 0)
        let s1 = section(uuid: "s1", name: "Outdoors", position: 1)
        let topics = [
            topic(uuid: "running", sections: [s0, s1]),
            topic(uuid: "cooking", sections: [s0])
        ]
        let list = GroupList(from: topics)

        #expect(list.sections == [
            .clientSection(name: "Sports"),
            .clientSection(name: "Outdoors")
        ])
        #expect(list.groupsBySection[.clientSection(name: "Sports")]?.map(\.id) == ["running", "cooking"])
        #expect(list.groupsBySection[.clientSection(name: "Outdoors")]?.map(\.id) == ["running"])
    }

    /// Regression guard against the OCT-1004 behavior. With OCT-1392, flipping `isFollowed`
    /// on any single topic must produce a byte-identical `(sections, groupsBySection)` —
    /// follow status is not part of the ordering contract anymore.
    @Test func followStatusDoesNotAffectOutput() {
        let s0 = section(uuid: "s0", name: "Sports", position: 0)
        let unfollowed = [
            topic(uuid: "a", isFollowed: false),
            topic(uuid: "b", sections: [s0], isFollowed: false),
            topic(uuid: "c", isFollowed: false)
        ]
        let mixedFollowed = [
            topic(uuid: "a", isFollowed: true),
            topic(uuid: "b", sections: [s0], isFollowed: true),
            topic(uuid: "c", isFollowed: true)
        ]

        let listA = GroupList(from: unfollowed)
        let listB = GroupList(from: mixedFollowed)

        #expect(listA.sections == listB.sections)
        #expect(listA.groupsBySection.mapValues { $0.map(\.id) }
                == listB.groupsBySection.mapValues { $0.map(\.id) })
    }

    /// Regression guard: an essential (force-followed) topic must appear at its incoming
    /// array index — it is not pinned to the top of any block.
    @Test func essentialTopicAppearsAtItsInputIndex() {
        let topics = [
            topic(uuid: "a", canChangeFollowStatus: true),
            topic(uuid: "b", canChangeFollowStatus: false),
            topic(uuid: "c", canChangeFollowStatus: true)
        ]
        let list = GroupList(from: topics)

        #expect(list.groupsBySection[.noSectionGroups]?.map(\.id) == ["a", "b", "c"])
    }
}
