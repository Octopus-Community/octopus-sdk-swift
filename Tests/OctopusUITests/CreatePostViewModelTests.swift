//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import OctopusCore
import UIKit
@testable import OctopusUI

/// Tests for the permission-gating logic used in CreatePostViewModel.
///
/// The VM itself requires a full OctopusSDK instance, so the derivation
/// functions are tested as pure helpers below (mirroring the pattern used
/// in PostDetailViewModelLockedStateTests).
struct CreatePostViewModelTests {

    // MARK: - defaultTopicId preselection

    @Test func defaultTopicPreselectedWhenFullyOpen() {
        let topics: [(uuid: String, name: String, permissions: UserPermissions)] = [
            ("topic-id", "Topic Name", .init(canAccess: true, canCreateChildren: true))
        ]
        let selected = resolveDefaultTopic(topicId: "topic-id", in: topics)
        #expect(selected != nil)
        #expect(selected?.topicId == "topic-id")
        #expect(selected?.name == "Topic Name")
    }

    @Test func defaultTopicDroppedWhenCanCreateChildrenFalse() {
        let topics: [(uuid: String, name: String, permissions: UserPermissions)] = [
            ("t", "T", .init(canAccess: true, canCreateChildren: false))
        ]
        let selected = resolveDefaultTopic(topicId: "t", in: topics)
        #expect(selected == nil)
    }

    @Test func defaultTopicDroppedWhenCanAccessFalse() {
        let topics: [(uuid: String, name: String, permissions: UserPermissions)] = [
            ("t", "T", .init(canAccess: false, canCreateChildren: true))
        ]
        let selected = resolveDefaultTopic(topicId: "t", in: topics)
        #expect(selected == nil)
    }

    @Test func defaultTopicDroppedWhenBothFalse() {
        let topics: [(uuid: String, name: String, permissions: UserPermissions)] = [
            ("t", "T", .init(canAccess: false, canCreateChildren: false))
        ]
        let selected = resolveDefaultTopic(topicId: "t", in: topics)
        #expect(selected == nil)
    }

    @Test func defaultTopicNilProducesNilSelection() {
        let topics: [(uuid: String, name: String, permissions: UserPermissions)] = [
            ("t", "T", .init(canAccess: true, canCreateChildren: true))
        ]
        let selected = resolveDefaultTopic(topicId: nil, in: topics)
        #expect(selected == nil)
    }

    @Test func defaultTopicIdNotInTopicsListProducesNil() {
        let topics: [(uuid: String, name: String, permissions: UserPermissions)] = [
            ("other", "Other", .init(canAccess: true, canCreateChildren: true))
        ]
        let selected = resolveDefaultTopic(topicId: "missing", in: topics)
        #expect(selected == nil)
    }

    // MARK: - topics list filtering

    @Test func topicsFilterExcludesRestrictedEntries() {
        let inputs: [(id: String, permissions: UserPermissions)] = [
            ("open", .init(canAccess: true, canCreateChildren: true)),
            ("noAccess", .init(canAccess: false, canCreateChildren: true)),
            ("noCreate", .init(canAccess: true, canCreateChildren: false)),
            ("both", .init(canAccess: false, canCreateChildren: false))
        ]
        let result = filterTopics(inputs)
        #expect(result.count == 1)
        #expect(result[0].topicId == "open")
    }

    @Test func topicsFilterKeepsAllWhenAllOpen() {
        let inputs: [(id: String, permissions: UserPermissions)] = [
            ("a", .default),
            ("b", .default)
        ]
        let result = filterTopics(inputs)
        #expect(result.count == 2)
    }

    @Test func topicsFilterProducesEmptyWhenAllRestricted() {
        let inputs: [(id: String, permissions: UserPermissions)] = [
            ("x", .init(canAccess: false, canCreateChildren: false))
        ]
        let result = filterTopics(inputs)
        #expect(result.isEmpty)
    }

    // MARK: - default image seeding (mirrors the branch inside CreatePostViewModel.init)

    @Test func defaultImageSeedsAttachment() {
        guard let onePixel = UIImage(systemName: "circle") else {
            Issue.record("Cannot create system image for test")
            return
        }
        guard let data = onePixel.pngData() else {
            Issue.record("Cannot encode system image to PNG")
            return
        }
        let attachment = seedImageAttachment(from: data)
        switch attachment {
        case let .image(imageAndData):
            #expect(imageAndData.imageData == data)
        default:
            Issue.record("Expected .image attachment")
        }
    }

    @Test func defaultImageNilProducesNoAttachment() {
        #expect(seedImageAttachment(from: nil) == nil)
    }

    @Test func defaultImageMalformedProducesNoAttachment() {
        let bogus = Data([0xFF, 0xD8, 0xFF]) // truncated JPEG header
        #expect(seedImageAttachment(from: bogus) == nil)
    }
}

// MARK: - Pure derivation helpers (mirror the logic in CreatePostViewModel)

extension CreatePostViewModelTests {
    struct DisplayableTopic: Equatable {
        let topicId: String
        let name: String
    }

    /// Mirrors the `resolveDefaultTopic` static helper in `CreatePostViewModel`.
    private func resolveDefaultTopic(topicId: String?,
                                     in topics: [(uuid: String, name: String,
                                                  permissions: UserPermissions)]) -> DisplayableTopic? {
        guard let topicId,
              let match = topics.first(where: { $0.uuid == topicId }),
              match.permissions.canAccess,
              match.permissions.canCreateChildren
        else { return nil }
        return DisplayableTopic(topicId: match.uuid, name: match.name)
    }

    /// Mirrors the filter applied to the topics-repository sink in `CreatePostViewModel.init`.
    private func filterTopics(_ topics: [(id: String, permissions: UserPermissions)]) -> [DisplayableTopic] {
        topics
            .filter { $0.permissions.canAccess && $0.permissions.canCreateChildren }
            .map { DisplayableTopic(topicId: $0.id, name: $0.id) }
    }

    /// Mirrors the image-seeding branch inside `CreatePostViewModel.init`.
    private func seedImageAttachment(from data: Data?) -> CreatePostViewModel.Attachment? {
        guard let data, let image = UIImage(data: data) else { return nil }
        return .image(ImageAndData(imageData: data, image: image))
    }
}
