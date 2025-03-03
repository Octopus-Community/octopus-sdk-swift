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

    @Published private(set) var isLoading = false
    @Published private(set) var dismiss = false
    @Published var alertError: DisplayableString?
    @Published var headline = ""
    @Published var text: String = ""
    @Published var picture: ImageAndData?
    @Published private(set) var headlineError: DisplayableString?
    @Published private(set) var textError: DisplayableString?
    @Published private(set) var pictureError: DisplayableString?
    @Published var selectedTopic: DisplayableTopic?
    @Published var topics = [DisplayableTopic]()
    @Published private(set) var userAvatar: Author.Avatar?
    @Published private(set) var hasChanges = false

    var sendButtonAvailable: Bool { !isLoading && headlineValid() && textValid() }
    private var sendAvailable: Bool { sendButtonAvailable && topicValid() }

    let headlineMaxLength = 100
    let textMaxLength = 3000

    let octopus: OctopusSDK
    private var storage = [AnyCancellable]()
    private var sendingCancellable: AnyCancellable?

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        Publishers.CombineLatest3(
            octopus.core.profileRepository.$profile,
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

        Publishers.CombineLatest4(
            $headline,
            $text,
            $picture,
            $selectedTopic)
            .sink { [unowned self] headline, text, picture, selectedTopic in
                hasChanges = !headline.isEmpty || !text.isEmpty || picture != nil || selectedTopic != nil
            }.store(in: &storage)

        $headline
            .removeDuplicates()
            .sink { [unowned self] headline in
                if headline.count > headlineMaxLength {
                    headlineError = .localizationKey("Error.TextTooLong_currentLength:\(headline.count)_maxLength:\(headlineMaxLength)")
                } else {
                    headlineError = nil
                }
            }.store(in: &storage)

        $text
            .removeDuplicates()
            .sink { [unowned self] text in
                if text.count > textMaxLength {
                    textError = .localizationKey("Error.TextTooLong_currentLength:\(text.count)_maxLength:\(textMaxLength)")
                } else {
                    textError = nil
                }
            }.store(in: &storage)

        $picture
            .removeDuplicates()
            .receive(on: DispatchQueue.main) // needed because we can reset the picture
            .sink { [unowned self] picture in
                if let picture {
                    let validator = octopus.core.validators.picture
                    switch validator.validate(picture.image) {
                    case .sideTooSmall, .ratioTooBig:
                        alertError = .localizationKey("Picture.Selection.Error_maxRatio:\(validator.maxRatioStr)_minSize:\(Int(validator.minSize))")
                        self.picture = nil
                    case .valid:
                        break
                    }
                }
                pictureError = nil
            }.store(in: &storage)
    }

    func send() {
        guard sendAvailable, let topic = selectedTopic else { return }

        isLoading = true

        let post = WritablePost(topicId: topic.topicId, headline: headline, text: text, imageData: picture?.imageData)

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
                        case .headline:
                            headlineError = .localizedString(multiErrorLocalizedString)
                        case .text:
                            textError = .localizedString(multiErrorLocalizedString)
                        case .picture:
                            pictureError = .localizedString(multiErrorLocalizedString)
                        }
                    }
                }
            case let .serverCall(serverError):
                alertError = serverError.displayableMessage
            }
        }
    }

    private func headlineValid() -> Bool {
        return !headline.isEmpty && headline.count <= headlineMaxLength
    }

    private func textValid() -> Bool {
        return text.count <= textMaxLength
    }

    private func topicValid() -> Bool {
        return selectedTopic != nil
    }
}
