//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import UIKit
@testable import OctopusCore
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

    // MARK: - default images seeding

    @MainActor
    @Test func seedImagesKeepsOrderAndDropsUndecodable() {
        let first = Self.pngData(width: 100, height: 100)
        let second = Self.pngData(width: 120, height: 100)
        let bogus = Data([0xFF, 0xD8, 0xFF]) // truncated JPEG header
        let seeded = CreatePostViewModel.seedImages(from: [first, bogus, second])
        #expect(seeded.map(\.imageData) == [first, second])
    }

    @MainActor
    @Test func seedImagesCapsAtMaxImageCount() {
        let datas = (0..<12).map { Self.pngData(width: 100 + $0, height: 100) }
        let seeded = CreatePostViewModel.seedImages(from: datas)
        #expect(seeded.count == Validators.Post.maxImageCount)
        #expect(seeded.map(\.imageData) == Array(datas.prefix(Validators.Post.maxImageCount)))
    }

    @MainActor
    @Test func seedImagesFromNoDataIsEmpty() {
        #expect(CreatePostViewModel.seedImages(from: []).isEmpty)
    }

    // MARK: - picked images

    @MainActor
    @Test func appendingCapsAtMaxImageCount() {
        let current = (0..<9).map { Self.imageAndData(width: 100 + $0, height: 100) }
        let new = (0..<3).map { Self.imageAndData(width: 200 + $0, height: 100) }
        let result = CreatePostViewModel.appending(new, to: current)
        #expect(result.count == Validators.Post.maxImageCount)
        #expect(Array(result.prefix(9)).map(\.imageData) == current.map(\.imageData))
        #expect(result.last?.imageData == new.first?.imageData)
    }

    @MainActor
    @Test func appendingKeepsTheOrderOfThePick() {
        let current = [Self.imageAndData(width: 100, height: 100)]
        let new = [Self.imageAndData(width: 110, height: 100), Self.imageAndData(width: 120, height: 100)]
        let result = CreatePostViewModel.appending(new, to: current)
        #expect(result.map(\.imageData) == (current + new).map(\.imageData))
    }

    @MainActor
    @Test func invalidPictureInSelectionIsDroppedAlone() {
        let valid1 = Self.imageAndData(width: 100, height: 100)
        let invalid = Self.imageAndData(width: 1, height: 1000)
        let valid2 = Self.imageAndData(width: 120, height: 100)
        let result = CreatePostViewModel.dropInvalidPictures([valid1, invalid, valid2])
        #expect(result.kept.map(\.imageData) == [valid1.imageData, valid2.imageData])
        #expect(result.hadInvalid)
    }

    @MainActor
    @Test func validPicturesAreAllKept() {
        let images = [Self.imageAndData(width: 100, height: 100), Self.imageAndData(width: 120, height: 100)]
        let result = CreatePostViewModel.dropInvalidPictures(images)
        #expect(result.kept.map(\.imageData) == images.map(\.imageData))
        #expect(!result.hadInvalid)
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
    @Test(arguments: [false, true])
    func shortTextEnablesThePublishButton(hasImage: Bool) {
        // A post text has no minimum beyond one visible character.
        #expect(CreatePostViewModel.canSend(text: "a", hasImage: hasImage, poll: nil, textRequired: true,
                                            isLoading: false))
    }

    @MainActor
    @Test func blankTextWithoutImageKeepsThePublishButtonDisabled() {
        #expect(!CreatePostViewModel.canSend(text: "  \n ", hasImage: false, poll: nil, textRequired: true,
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

    // MARK: - picture to reveal

    @MainActor
    @Test func pictureErrorWithIndexRevealsThatPicture() {
        let images = [Self.imageAndData(width: 100, height: 100), Self.imageAndData(width: 120, height: 120)]
        #expect(CreatePostViewModel.pictureToReveal(for: [1], in: images) == images[1].thumbnailId)
    }

    @MainActor
    @Test func firstValidIndexIsRevealedWhenSeveralErrorsCarryOne() {
        let images = [Self.imageAndData(width: 100, height: 100), Self.imageAndData(width: 120, height: 120),
                      Self.imageAndData(width: 140, height: 140)]
        #expect(CreatePostViewModel.pictureToReveal(for: [nil, 7, 2, 0], in: images) == images[2].thumbnailId)
    }

    @MainActor
    @Test(arguments: [5, -1, 2])
    func outOfRangeIndexRevealsNothing(_ index: Int) {
        let images = [Self.imageAndData(width: 100, height: 100), Self.imageAndData(width: 120, height: 120)]
        #expect(CreatePostViewModel.pictureToReveal(for: [index], in: images) == nil)
    }

    @MainActor
    @Test func errorWithoutIndexRevealsNothing() {
        let images = [Self.imageAndData(width: 100, height: 100)]
        #expect(CreatePostViewModel.pictureToReveal(for: [nil, nil], in: images) == nil)
        #expect(CreatePostViewModel.pictureToReveal(for: [], in: images) == nil)
    }

    @MainActor
    @Test func noPictureToRevealWithoutImages() {
        #expect(CreatePostViewModel.pictureToReveal(for: [0], in: []) == nil)
    }

    // MARK: - picture to reveal from the server's refusal

    private typealias SendErrors = ValidationErrors<SendPost.Field, SendPost.ErrorDetail>

    private static func sendError(_ detail: SendPost.ErrorDetail = .fileSizeTooBig, imageIndex: Int? = nil)
    -> SendErrors.Error {
        .init(localizedMessage: "refused", detail: detail, imageIndex: imageIndex)
    }

    @MainActor
    @Test func refusedPhotoOfThePictureFieldIsRevealed() {
        let images = [Self.imageAndData(width: 100, height: 100), Self.imageAndData(width: 120, height: 120)]
        let validation = SendErrors(errors: [.linkedToField(.picture): [Self.sendError(imageIndex: 1)]])
        #expect(CreatePostViewModel.pictureToReveal(from: validation, in: images) == images[1].thumbnailId)
    }

    @MainActor
    @Test func errorsOnOtherFieldsRevealNothingEvenWithAnIndex() {
        let images = [Self.imageAndData(width: 100, height: 100), Self.imageAndData(width: 120, height: 120)]
        let validation = SendErrors(errors: [
            .linkedToField(.text): [Self.sendError(.missingText, imageIndex: 1)],
            .alert: [Self.sendError(.unknown, imageIndex: 0)]
        ])
        #expect(CreatePostViewModel.pictureToReveal(from: validation, in: images) == nil)
    }

    @MainActor
    @Test func pictureFieldErrorsWithoutAnyValidIndexRevealNothing() {
        let images = [Self.imageAndData(width: 100, height: 100)]
        let validation = SendErrors(errors: [
            .linkedToField(.picture): [Self.sendError(), Self.sendError(imageIndex: 4)]])
        #expect(CreatePostViewModel.pictureToReveal(from: validation, in: images) == nil)
    }

    // MARK: - images to cache after publication

    private static func media(_ name: String, kind: OctopusCore.Media.Kind = .image) -> OctopusCore.Media {
        OctopusCore.Media(
            url: URL(string: "https://example.com/\(name)")!, thumbnailUrl: nil,
            kind: kind, size: CGSize(width: 10, height: 10), videoId: kind == .video ? name : nil)
    }

    @MainActor
    @Test func sentImagesAreCachedUnderTheURLOfTheImageAtTheSameIndex() {
        let medias = [Self.media("a.jpg"), Self.media("b.jpg"), Self.media("c.jpg")]
        let datas = [Data([1]), Data([2]), Data([3])]
        let pairs = CreatePostViewModel.imagesToCache(sent: datas, in: medias)
        #expect(pairs.map(\.url) == medias.map(\.url))
        #expect(pairs.map(\.imageData) == datas)
    }

    @MainActor
    @Test func videosOfThePostAreSkippedWhenPairingImages() {
        let medias = [Self.media("v1", kind: .video), Self.media("a.jpg"), Self.media("v2", kind: .video),
                      Self.media("b.jpg")]
        let pairs = CreatePostViewModel.imagesToCache(sent: [Data([1]), Data([2])], in: medias)
        #expect(pairs.map(\.url.lastPathComponent) == ["a.jpg", "b.jpg"])
        #expect(pairs.map(\.imageData) == [Data([1]), Data([2])])
    }

    @MainActor
    @Test func nothingIsCachedWhenCountsDiffer() {
        // Which photo is missing is unknown: pairing by position would cache a photo under another one's URL.
        let medias = [Self.media("a.jpg"), Self.media("b.jpg")]
        #expect(CreatePostViewModel.imagesToCache(sent: [Data([1])], in: medias).isEmpty)
        #expect(CreatePostViewModel.imagesToCache(sent: [Data([1]), Data([2]), Data([3])], in: medias).isEmpty)
    }

    @MainActor
    @Test func nothingIsCachedWithoutSentImages() {
        #expect(CreatePostViewModel.imagesToCache(sent: [], in: [Self.media("a.jpg")]).isEmpty)
        #expect(CreatePostViewModel.imagesToCache(sent: [Data([1])], in: []).isEmpty)
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

    /// A plain image of the given size in pixels, PNG-encoded. Each size gives different bytes.
    static func pngData(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.pngData { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    static func imageAndData(width: Int, height: Int) -> ImageAndData {
        let data = pngData(width: width, height: height)
        return ImageAndData(imageData: data, image: UIImage(data: data)!)
    }
}
