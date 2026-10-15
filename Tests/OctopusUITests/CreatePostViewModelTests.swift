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

    @Test func defaultImageSeedsImage() {
        guard let onePixel = UIImage(systemName: "circle") else {
            Issue.record("Cannot create system image for test")
            return
        }
        guard let data = onePixel.pngData() else {
            Issue.record("Cannot encode system image to PNG")
            return
        }
        #expect(seedImage(from: data)?.imageData == data)
    }

    @Test func defaultImageNilProducesNoImage() {
        #expect(seedImage(from: nil) == nil)
    }

    @Test func defaultImageMalformedProducesNoImage() {
        let bogus = Data([0xFF, 0xD8, 0xFF]) // truncated JPEG header
        #expect(seedImage(from: bogus) == nil)
    }

    // MARK: - poll mapping

    @Test func editablePollMapsOptionsInOrder() {
        var poll = EditablePoll()
        poll.options[0].text = "Red"
        poll.options[1].text = "Blue"
        #expect(poll.writablePoll.options.map(\.text) == ["Red", "Blue"])
    }

    // MARK: - hasChanges

    @MainActor
    @Test func hasChangesWhenImageDeletedButPollRemains() {
        #expect(CreatePostViewModel.hasChanges(text: "", hasImage: false, hasPoll: true,
                                               selectedTopicId: "topic", defaultTopicId: "topic"))
    }

    @MainActor
    @Test func hasChangesWhenPollDeletedButImageRemains() {
        #expect(CreatePostViewModel.hasChanges(text: "", hasImage: true, hasPoll: false,
                                               selectedTopicId: "topic", defaultTopicId: "topic"))
    }

    @MainActor
    @Test func noChangesWhenDraftIsEmptyAndTopicIsDefault() {
        #expect(!CreatePostViewModel.hasChanges(text: "", hasImage: false, hasPoll: false,
                                                selectedTopicId: "topic", defaultTopicId: "topic"))
    }

    @MainActor
    @Test func hasChangesWhenTopicChanged() {
        #expect(CreatePostViewModel.hasChanges(text: "", hasImage: false, hasPoll: false,
                                               selectedTopicId: "other", defaultTopicId: "topic"))
    }

    // MARK: - publish button

    private static let validPoll = WritablePoll(options: [.init(text: "Red"), .init(text: "Blue")])

    @MainActor
    @Test func imageWithoutTextCannotBePublishedWhenTextIsRequired() {
        #expect(!CreatePostViewModel.canSend(text: "", hasImage: true, poll: nil, textRequired: true,
                                             isLoading: false))
    }

    @MainActor
    @Test func imageWithoutTextCanBePublishedWhenTextIsOptional() {
        #expect(CreatePostViewModel.canSend(text: "", hasImage: true, poll: nil, textRequired: false,
                                            isLoading: false))
    }

    @MainActor
    @Test func imageWithBlankTextCanBePublishedWhenTextIsOptional() {
        #expect(CreatePostViewModel.canSend(text: "  \n", hasImage: true, poll: nil, textRequired: false,
                                            isLoading: false))
    }

    @MainActor
    @Test(arguments: [false, true])
    func draftWithoutImageNeedsTextEvenWhenTextIsOptional(hasPoll: Bool) {
        // Also covers removing the image while the text is empty: publishing is disabled again.
        #expect(!CreatePostViewModel.canSend(text: "", hasImage: false, poll: hasPoll ? Self.validPoll : nil,
                                             textRequired: false, isLoading: false))
    }

    @MainActor
    @Test func imageAndPollWithoutTextCanBePublishedWhenTextIsOptional() {
        #expect(CreatePostViewModel.canSend(text: "", hasImage: true, poll: Self.validPoll, textRequired: false,
                                            isLoading: false))
    }

    @MainActor
    @Test func invalidPollBlocksPublishingWhenTextIsOptional() {
        let invalidPoll = WritablePoll(options: [.init(text: "Red")])
        #expect(!CreatePostViewModel.canSend(text: "", hasImage: true, poll: invalidPoll, textRequired: false,
                                             isLoading: false))
    }

    @MainActor
    @Test func shortTextKeepsThePublishButtonEnabled() {
        // The minimum length is reported on tap, not by disabling the button.
        #expect(CreatePostViewModel.canSend(text: "abc", hasImage: true, poll: nil, textRequired: false,
                                            isLoading: false))
    }

    @MainActor
    @Test func tooLongTextBlocksPublishingWhenTextIsOptional() {
        let text = String(repeating: "a", count: Validators.Post.maxTextLength + 1)
        #expect(!CreatePostViewModel.canSend(text: text, hasImage: true, poll: nil, textRequired: false,
                                             isLoading: false))
    }

    @MainActor
    @Test func loadingBlocksPublishing() {
        #expect(!CreatePostViewModel.canSend(text: "", hasImage: true, poll: nil, textRequired: false,
                                             isLoading: true))
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
    private func seedImage(from data: Data?) -> ImageAndData? {
        guard let data, let image = UIImage(data: data) else { return nil }
        return ImageAndData(imageData: data, image: image)
    }
}
