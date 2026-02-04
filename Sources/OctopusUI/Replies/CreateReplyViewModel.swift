//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore
import UIKit

@MainActor
class CreateReplyViewModel: ObservableObject {

    @Published private(set) var isLoading = false
    @Published var alertError: DisplayableString?
    @Published var text: String = ""
    @Published var picture: ImageAndData?
    @Published private(set) var textError: DisplayableString?
    @Published private(set) var pictureError: DisplayableString?
    @Published private(set) var hasChanges = false
    @Published private(set) var userHasAcceptedCgu = false

    var sendAvailable: Bool {
        validator.validate(reply: WritableReply(commentId: commentId, text: text, imageData: picture?.imageData))
    }

    var textMaxLength: Int { validator.maxTextLength }

    let communityGuidelinesUrl: URL
    let privacyPolicyUrl: URL
    let termsOfUseUrl: URL

    let octopus: OctopusSDK
    let commentId: String
    private let translationStore: ContentTranslationPreferenceStore
    private let validator: Validators.Reply
    private var storage = [AnyCancellable]()
    private var replyReceivedCancellable: AnyCancellable?

    private let ensureConnected: (UserAction) -> Bool

    private var isWaitingToSendReply = false

    init(octopus: OctopusSDK, commentId: String,
         translationStore: ContentTranslationPreferenceStore,
         ensureConnected: @escaping (UserAction) -> Bool) {
        self.octopus = octopus
        self.commentId = commentId
        self.translationStore = translationStore
        self.ensureConnected = ensureConnected

        let externalLinksRepository = octopus.core.externalLinksRepository
        communityGuidelinesUrl = externalLinksRepository.communityGuidelines
        privacyPolicyUrl = externalLinksRepository.privacyPolicy
        termsOfUseUrl = externalLinksRepository.termsOfUse

        validator = self.octopus.core.validators.reply

        octopus.core.configRepository.communityConfigPublisher
            .map { $0?.forceLoginOnStrongActions }
            .removeDuplicates()
            .sink { [unowned self] forceLoginOnStrongActions in
                guard forceLoginOnStrongActions != nil else {
                    return
                }
                if isWaitingToSendReply {
                    isWaitingToSendReply = false
                    DispatchQueue.main.async { [weak self] in
                        self?.send()
                    }
                }
            }.store(in: &storage)

        octopus.core.profileRepository.profilePublisher
            .sink { [unowned self] profile in
                guard let profile else { return }
                userHasAcceptedCgu = profile.hasAcceptedCgu
                if !profile.isGuest || profile.hasConfirmedNickname {
                    if isWaitingToSendReply {
                        isWaitingToSendReply = false
                        DispatchQueue.main.async { [weak self] in
                            self?.send()
                        }
                    }
                }
            }.store(in: &storage)

        $text
            .removeDuplicates()
            .sink { [unowned self] text in
                if !validator.validate(text: text) {
                    textError = .localizationKey("Error.Text.TooLong_currentLength:\(text.count)_maxLength:\(textMaxLength)")
                } else {
                    textError = nil
                }
            }.store(in: &storage)

        $picture
            .removeDuplicates()
            .receive(on: DispatchQueue.main) // needed because we can reset the picture
            .sink { [weak self] picture in
                guard let self else { return }
                if let picture {
                    switch validator.validate(picture: picture.image) {
                    case .sideTooSmall, .ratioTooBig:
                        alertError = .localizationKey("Picture.Selection.Error_maxRatio:\(validator.maxRatioStr)_minSize:\(Int(validator.minSize))")
                        self.picture = nil
                    case .valid:
                        break
                    }
                }
                pictureError = nil
            }.store(in: &storage)

        Publishers.CombineLatest(
            $text.removeDuplicates(),
            $picture.removeDuplicates())
            .sink { [unowned self] text, picture in
                hasChanges = (!text.isEmpty) || (picture != nil)
            }.store(in: &storage)
    }

    func send() {
        let reply = WritableReply(commentId: commentId, text: text, imageData: picture?.imageData)
        guard validator.validate(reply: reply) else { return }

        isLoading = true

        guard ensureConnected(.reply) else {
            isWaitingToSendReply = true
            isLoading = false
            return
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64(0.25 * 1_000_000_000))
            await send(reply: reply)
        }
    }

    private func send(reply: WritableReply) async {
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
                    self.alertError = .localizedString(multiErrorLocalizedString)
                }
            case let .serverCall(serverError):
                self.alertError = serverError.displayableMessage
            }
            // do not send the message if we cannot update the profile
            return
        }
        do {
            // let enough time for the keyboard to remove itself
            let (createdReply, imageData) = try await octopus.core.repliesRepository.send(
                reply, parentIsTranslated: translationStore.displayTranslation(for: commentId))
            if let imageData, let image = UIImage(data: imageData), let imageUrl = createdReply.medias.first?.url {
                try? ImageCache.content.store(ImageAndData(imageData: imageData, image: image), url: imageUrl)
            }
            let replyId = createdReply.uuid
            // only stop loading when the new reply has been received in the feed
            replyReceivedCancellable = octopus.core.commentsRepository.getComment(uuid: commentId)
                .replaceError(with: nil)
                .map { comment in
                    guard let comment else { return Empty<Void, Never>().eraseToAnyPublisher() }
                    return comment.oldestFirstRepliesFeed?.$items
                        .filter {
                            guard let items = $0 else { return false }
                            return items.contains(where: { $0.uuid == replyId })
                        }
                        .map { _ in }
                        .first()
                        .eraseToAnyPublisher()
                    ?? Just(()).eraseToAnyPublisher() // This should not happen
                }
                .switchToLatest()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    guard let self else { return }
                    DispatchQueue.main.async { [weak self] in
                        self?.picture = nil
                        self?.text = ""
                        self?.isLoading = false
                    }
                    replyReceivedCancellable = nil
                }
        } catch {
            switch error {
            case let .validation(argumentError):
                var ignoreMissingParentError = false
                // special case where the error missingParent is returned: reload the comment to check that it has not
                // been deleted
                for error in argumentError.errors.values.flatMap({ $0 }) {
                    if case .missingParent = error.detail {
                        do {
                            try await octopus.core.commentsRepository.fetchComment(uuid: commentId)
                        } catch {
                            ignoreMissingParentError = true
                        }
                        break
                    }
                }
                for (displayKind, errors) in argumentError.errors {
                    let errors = if ignoreMissingParentError {
                        errors.filter {
                            guard case .missingParent = $0.detail else { return true }
                            return false
                        }
                    } else {
                        errors
                    }
                    guard !errors.isEmpty else { continue }
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
                        }
                    }
                }
            case let .serverCall(serverError):
                alertError = serverError.displayableMessage
            }
            isLoading = false
        }
    }

    private func textValid() -> Bool {
        return !text.isEmpty && text.count <= textMaxLength
    }
}
