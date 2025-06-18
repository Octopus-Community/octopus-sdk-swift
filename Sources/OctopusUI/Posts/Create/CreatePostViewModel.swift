//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore
import UIKit

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

    var sendButtonAvailable: Bool {
        !isLoading &&
        validator.validate(text: text, attachment: .init(from: attachment), ignoreTooShort: true).isSuccess &&
        validator.validate(attachment: .init(from: attachment))
    }

    var textMaxLength: Int { validator.maxTextLength }
    var textMinLength: Int { validator.minTextLength }

    let octopus: OctopusSDK
    private let validator: Validators.Post
    private let pollValidator: Validators.Poll
    private var storage = [AnyCancellable]()
    private var sendingCancellable: AnyCancellable?

    init(octopus: OctopusSDK) {
        self.octopus = octopus
        validator = octopus.core.validators.post
        pollValidator = octopus.core.validators.poll

        Publishers.CombineLatest3(
            octopus.core.profileRepository.profilePublisher,
            $alertError,
            $isLoading
        ).sink { [unowned self] profile, currentError, isLoading in
            guard let profile else {
                if currentError == nil && !isLoading {
                    dismiss = true
                }
                return
            }
            if let pictureUrl = profile.pictureUrl {
                userAvatar = .image(url: pictureUrl, name: profile.nickname)
            } else {
                userAvatar = .defaultImage(name: profile.nickname)
            }
        }.store(in: &storage)

        octopus.core.topicsRepository.$topics.sink { [unowned self] in
            topics = $0.map { DisplayableTopic(topicId: $0.uuid, name: $0.name) }
        }.store(in: &storage)

        Publishers.CombineLatest3(
            $text,
            $attachment,
            $selectedTopic)
            .sink { [unowned self] text, picture, selectedTopic in
                hasChanges = !text.isEmpty || attachment != nil || selectedTopic != nil
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
            .sink { [unowned self] attachment in
                switch attachment {
                case let .image(imageAndData):
                    let validator = octopus.core.validators.picture
                    switch validator.validate(imageAndData.image) {
                    case .sideTooSmall, .ratioTooBig:
                        alertError = .localizationKey("Picture.Selection.Error_maxRatio:\(validator.maxRatioStr)_minSize:\(Int(validator.minSize))")
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
        let post = WritablePost(topicId: topic.topicId, text: text, attachment: .init(from: attachment))
        switch validator.validate(text: post.text, attachment: post.attachment) {
        case let .failure(error):
            if error == .tooShort {
                textError = .localizationKey("Error.Text.TooShort_minLength:\(textMinLength)")
            }
        default: break
        }
        guard validator.validate(post: post) else { return }

        isLoading = true

        Task {
            await send(post: post)
            isLoading = false
        }
    }

    private func send(post: WritablePost) async {
        do {
            let (createdPost, imageData) = try await octopus.core.postsRepository.send(post)
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
            }
        }
    }

    func createPoll() {
        attachment = .poll(EditablePoll(validator: pollValidator))
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
