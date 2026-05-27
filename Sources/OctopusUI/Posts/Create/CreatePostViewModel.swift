//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore
import UIKit
import SwiftUI

@MainActor
class CreatePostViewModel: ObservableObject {
    struct DisplayableTopic: Equatable, Hashable {
        let topicId: String
        let name: String
    }

    enum Attachment: Equatable {
        case image(ImageAndData)
        case poll(EditablePoll)

        var hasImage: Bool {
            switch self {
            case .image: return true
            default: return false
            }
        }

        var hasPoll: Bool {
            switch self {
            case .poll: return true
            default: return false
            }
        }
    }

    @Published private(set) var isLoading = false
    @Published private(set) var dismiss = false
    @Published var alertError: DisplayableString?
    @Published var text: String = ""
    @Published var attachment: Attachment?
    @Published private(set) var textError: DisplayableString?
    @Published private(set) var pictureError: DisplayableString?
    @Published private(set) var pollError: DisplayableString?
    @Published var selectedTopic: DisplayableTopic?
    @Published var topics = [DisplayableTopic]()
    @Published private(set) var userAvatar: Author.Avatar?
    @Published private(set) var hasChanges = false
    @Published var authenticationAction: ConnectedActionReplacement?
    @Published private(set) var userHasAcceptedCgu = false

    let communityGuidelinesUrl: URL
    let privacyPolicyUrl: URL
    let termsOfUseUrl: URL

    var sendButtonAvailable: Bool {
        !isLoading &&
        Validators.Post.validate(text: text, attachment: .init(from: attachment), ignoreTooShort: true).isSuccess &&
        Validators.Post.validate(attachment: .init(from: attachment))
    }

    var textMaxLength: Int { Validators.Post.maxTextLength }
    var textMinLength: Int { Validators.Post.minTextLength }

    let octopus: OctopusSDK
    private var storage = [AnyCancellable]()
    private var sendingCancellable: AnyCancellable?

    let connectedActionChecker: ConnectedActionChecker
    var authenticationActionBinding: Binding<ConnectedActionReplacement?> {
        Binding(
            get: { self.authenticationAction },
            set: { self.authenticationAction = $0 }
        )
    }

    private var isWaitingToSendPost = false
    private let defaultTopicId: String?
    private let cta: WritableCTA?
    private let creationSource: PostsRepository.CreationSource

    init(octopus: OctopusSDK,
         withPoll: Bool,
         defaultTopicId: String?,
         defaultText: String? = nil,
         defaultImage: Data? = nil,
         cta: WritableCTA? = nil,
         creationSource: PostsRepository.CreationSource = .user) {
        self.octopus = octopus
        self.defaultTopicId = defaultTopicId
        self.cta = cta
        self.creationSource = creationSource
        connectedActionChecker = ConnectedActionChecker(octopus: octopus)
        selectedTopic = Self.resolveDefaultTopic(
            topicId: defaultTopicId,
            in: octopus.core.topicsRepository.topics
        )

        if let defaultText { self.text = defaultText }
        if let defaultImage, let image = UIImage(data: defaultImage) {
            self.attachment = .image(ImageAndData(imageData: defaultImage, image: image))
        }

        let externalLinksRepository = octopus.core.externalLinksRepository
        communityGuidelinesUrl = externalLinksRepository.communityGuidelines
        privacyPolicyUrl = externalLinksRepository.privacyPolicy
        termsOfUseUrl = externalLinksRepository.termsOfUse

        if withPoll {
            createPoll()
        }

        octopus.core.configRepository.communityConfigPublisher
            .map { $0?.forceLoginOnStrongActions }
            .removeDuplicates()
            .sink { [unowned self] forceLoginOnStrongActions in
                guard forceLoginOnStrongActions != nil else {
                    return
                }
                if isWaitingToSendPost {
                    isWaitingToSendPost = false
                    DispatchQueue.main.async { [weak self] in
                        self?.send()
                    }
                }
            }.store(in: &storage)

        Publishers.CombineLatest3(
            octopus.core.profileRepository.profilePublisher,
            $alertError,
            $isLoading.removeDuplicates()
        ).sink { [unowned self] profile, _, _ in
            guard let profile else { return }
            userHasAcceptedCgu = profile.hasAcceptedCgu
            if !profile.isGuest || profile.hasConfirmedNickname {
                if isWaitingToSendPost {
                    isWaitingToSendPost = false
                    DispatchQueue.main.async { [weak self] in
                        self?.send()
                    }
                }
            }
            if let pictureUrl = profile.pictureUrl {
                userAvatar = .image(url: pictureUrl, name: profile.nickname)
            } else {
                userAvatar = .defaultImage(name: profile.nickname)
            }
        }.store(in: &storage)

        octopus.core.topicsRepository.$topics.sink { [unowned self] newTopics in
            topics = newTopics
                .filter { $0.permissions.canAccess && $0.permissions.canCreateChildren }
                .map { DisplayableTopic(topicId: $0.uuid, name: $0.name) }
            if selectedTopic == nil {
                selectedTopic = Self.resolveDefaultTopic(topicId: defaultTopicId, in: newTopics)
            }
        }.store(in: &storage)

        Publishers.CombineLatest3(
            $text,
            $attachment,
            $selectedTopic)
            .sink { [unowned self] text, _, selectedTopic in
                hasChanges = !text.isEmpty || attachment != nil || selectedTopic?.topicId != defaultTopicId
            }.store(in: &storage)

        $text
            .removeDuplicates()
            .sink { [unowned self] text in
                if text.count > textMaxLength {
                    textError = .localizationKey("Error.Text.TooLong_currentLength:\(text.count)_maxLength:\(textMaxLength)")
                } else {
                    textError = nil
                }
            }.store(in: &storage)

        $attachment
            .removeDuplicates()
            .receive(on: DispatchQueue.main) // needed because we can reset the picture
            .sink { [weak self] attachment in
                guard let self else { return }
                switch attachment {
                case let .image(imageAndData):
                    switch Validators.Picture.validate(imageAndData.image) {
                    case .sideTooSmall, .ratioTooBig:
                        alertError = .localizationKey(
                            "Picture.Selection.Error_maxRatio:\(Validators.Picture.maxRatioStr)_minSize:\(Int(Validators.Picture.minSize))")
                        self.attachment = nil
                    case .valid:
                        pictureError = nil
                    }
                case .poll:
                    // validation is done inside the EditablePoll directly
                    pollError = nil
                case .none:
                    pictureError = nil
                    pollError = nil
                }
            }.store(in: &storage)
    }

    func send() {
        guard let topic = selectedTopic else { return }
        let post = WritablePost(
            topicId: topic.topicId,
            text: text,
            attachment: .init(from: attachment),
            cta: cta
        )
        switch Validators.Post.validate(text: post.text, attachment: post.attachment) {
        case let .failure(error):
            if error == .tooShort {
                textError = .localizationKey("Error.Text.TooShort_minLength:\(textMinLength)")
            }
        default: break
        }
        guard Validators.Post.validate(post: post) else { return }

        guard connectedActionChecker.ensureConnected(action: .post, actionWhenNotConnected: authenticationActionBinding) else {
            isWaitingToSendPost = true
            isLoading = false
            return
        }

        isLoading = true

        Task {
            await send(post: post)
            isLoading = false
        }
    }

    private func send(post: WritablePost) async {
        do {
            if let profile = octopus.core.profileRepository.profile, !profile.hasAcceptedCgu {
                try await octopus.core.profileRepository.updateCurrentUserProfile(with: .init(
                    hasAcceptedCgu: .updated(true)
                ))
            }
        } catch {
            switch error {
            case let .validation(argumentError):
                for (_, errors) in argumentError.errors {
                    let multiErrorLocalizedString = errors.map(\.localizedMessage).joined(separator: "\n- ")
                    alertError = .localizedString(multiErrorLocalizedString)
                }
            case let .serverCall(serverError):
                alertError = serverError.displayableMessage
            case .other:
                alertError = .localizationKey("Error.Unknown")
            }
            // do not send the message if we cannot update the profile
            return
        }
        do {
            let (createdPost, imageData) = try await octopus.core.postsRepository.send(post, creationSource: creationSource)
            if let imageData, let image = UIImage(data: imageData), let imageUrl = createdPost.medias.first?.url {
                try? ImageCache.content.store(ImageAndData(imageData: imageData, image: image), url: imageUrl)
            }

            dismiss = true
        } catch {
            switch error {
            case let .validation(argumentError):
                for (displayKind, errors) in argumentError.errors {
                    let multiErrorLocalizedString = errors.map(\.localizedMessage).joined(separator: "\n- ")
                    switch displayKind {
                    case .alert:
                        alertError = .localizedString(multiErrorLocalizedString)
                    case let .linkedToField(field):
                        switch field {
                        case .text:
                            textError = .localizedString(multiErrorLocalizedString)
                        case .picture:
                            pictureError = .localizedString(multiErrorLocalizedString)
                        case .poll:
                            pollError = .localizedString(multiErrorLocalizedString)
                        }
                    }
                }
            case let .serverCall(serverError):
                alertError = serverError.displayableMessage
            case .other:
                alertError = .localizationKey("Error.Unknown")
            }
        }
    }

    func createPoll() {
        attachment = .poll(EditablePoll())
    }

    private static func resolveDefaultTopic(
        topicId: String?,
        in topics: [OctopusCore.Topic]
    ) -> DisplayableTopic? {
        guard let topicId,
              let match = topics.first(where: { $0.uuid == topicId }),
              match.permissions.canAccess,
              match.permissions.canCreateChildren
        else { return nil }
        return DisplayableTopic(topicId: match.uuid, name: match.name)
    }

    private func topicValid() -> Bool {
        return selectedTopic != nil
    }
}

private extension WritablePost.Attachment {
    init?(from attachment: CreatePostViewModel.Attachment?) {
        switch attachment {
        case let .image(imageAndData):
            self = .image(imageAndData.imageData)
        case let .poll(editablePoll):
            let poll = WritablePoll(options: editablePoll.options.map { .init(text: $0.text) })
            self = .poll(poll)
        case .none: return nil
        }
    }
}
