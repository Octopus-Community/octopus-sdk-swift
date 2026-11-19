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

    @Published private(set) var isLoading = false
    @Published private(set) var dismiss = false
    @Published var alertError: DisplayableString?
    @Published var text: String = ""
    /// The images of the post, in the order they are shown and sent.
    @Published var images: [ImageAndData] = []
    @Published var poll: EditablePoll?
    @Published private(set) var textError: DisplayableString?
    @Published private(set) var pictureError: DisplayableString?
    /// The id of the picture the server refused, for the images strip to scroll to. The strip resets it to `nil`
    /// as soon as it has taken it into account, so that the same refusal on a retry scrolls again.
    @Published var pictureToReveal: String?
    @Published private(set) var pollError: DisplayableString?
    @Published var selectedTopic: DisplayableTopic?
    @Published var topics = [DisplayableTopic]()
    @Published private(set) var userAvatar: Author.Avatar?
    @Published private(set) var hasChanges = false
    @Published var authenticationAction: ConnectedActionReplacement?
    @Published private(set) var userHasAcceptedCgu = false
    /// Per-content-type creation options for posts. Default `true` until the community
    /// config is loaded, so behaviour is unchanged unless the community disables a capability.
    @Published private(set) var picturesEnabled = true
    @Published private(set) var pollsEnabled = true
    /// Whether a post needs text. Default `true` until the community config is loaded; when `false`, a post
    /// with an image can be published without text.
    @Published private(set) var textRequired = true
    /// How the community requires legal acceptance. Default `.implicit` until the config loads.
    @Published private(set) var termsAcceptanceMode: TermsAcceptanceMode = .implicit
    /// The community's custom consent wordings, `nil` for the SDK ones (until the config loads, or when unset).
    @Published private(set) var consentTexts: ConsentTexts?
    /// Drives the explicit terms-acceptance bottom sheet (explicit modes only).
    @Published var displayConsentSheet = false
    /// Whether the nickname choice screen follows the consent sheet currently presented, which changes its button
    /// label: accepting then leads to that screen instead of publishing.
    @Published private(set) var consentSheetLeadsToNicknameChoice = false
    /// Set once the user accepts in the consent sheet, so the re-entered `send()` bypasses the gate.
    private var explicitConsentGivenThisSession = false

    let communityGuidelinesUrl: URL
    let privacyPolicyUrl: URL
    let termsOfUseUrl: URL

    var sendButtonAvailable: Bool {
        Self.canSend(text: text, hasImage: !images.isEmpty, poll: writablePoll, textRequired: textRequired,
                     isLoading: isLoading)
    }

    private var writablePoll: WritablePoll? {
        poll?.writablePoll
    }

    var textMaxLength: Int { Validators.Post.maxTextLength }

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

    private var pendingSend: PendingSendReason?
    private let defaultTopicId: String?
    private let cta: WritableCTA?
    private let creationSource: PostsRepository.CreationSource
    /// Host signing closure for a prefilled-share image. `nil` for member-initiated posts.
    private let bridgeShareSignature: (@Sendable (_ fingerprint: String) async throws -> String?)?

    init(octopus: OctopusSDK,
         withPoll: Bool,
         defaultTopicId: String?,
         defaultText: String? = nil,
         defaultImages: [Data] = [],
         cta: WritableCTA? = nil,
         creationSource: PostsRepository.CreationSource = .user,
         bridgeShareSignature: (@Sendable (_ fingerprint: String) async throws -> String?)? = nil) {
        self.octopus = octopus
        self.defaultTopicId = defaultTopicId
        self.cta = cta
        self.creationSource = creationSource
        self.bridgeShareSignature = bridgeShareSignature
        connectedActionChecker = ConnectedActionChecker(octopus: octopus)
        selectedTopic = Self.resolveDefaultTopic(
            topicId: defaultTopicId,
            in: octopus.core.topicsRepository.topics
        )

        if let defaultText { self.text = defaultText }
        images = Self.seedImages(from: defaultImages)

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
                if let pendingSend, pendingSend.resumesOnConfigChange {
                    self.pendingSend = nil
                    DispatchQueue.main.async { [weak self] in
                        self?.send()
                    }
                }
            }.store(in: &storage)

        octopus.core.configRepository.communityConfigPublisher
            .map { $0?.termsAcceptanceMode ?? .implicit }
            .removeDuplicates()
            .sink { [unowned self] mode in
                termsAcceptanceMode = mode
            }.store(in: &storage)

        octopus.core.configRepository.communityConfigPublisher
            .map { $0?.consentTexts }
            .removeDuplicates()
            .sink { [unowned self] in consentTexts = $0 }
            .store(in: &storage)

        octopus.core.configRepository.communityConfigPublisher
            .map { ($0?.contentOptions ?? .allEnabled).post }
            .removeDuplicates()
            .sink { [unowned self] postOptions in
                picturesEnabled = postOptions.enablePictures
                pollsEnabled = postOptions.enablePolls
                textRequired = postOptions.textRequired
                // Safety net (not bypassable): if polls are disabled, never leave a poll editor open.
                // Pictures don't clear existing/prefilled images — bridge images are unaffected.
                if !postOptions.enablePolls, poll != nil {
                    poll = nil
                }
            }.store(in: &storage)

        Publishers.CombineLatest3(
            octopus.core.profileRepository.profilePublisher,
            $alertError,
            $isLoading.removeDuplicates()
        ).sink { [unowned self] profile, _, _ in
            resolvePendingSend(profile: profile)
            guard let profile else { return }
            userHasAcceptedCgu = profile.hasAcceptedCgu
            userAvatar = .member(pictureUrl: profile.pictureUrl, name: profile.nickname,
                                 community: profile.defaultAvatar)
        }.store(in: &storage)

        octopus.core.topicsRepository.$topics.sink { [unowned self] newTopics in
            topics = newTopics
                .filter { $0.permissions.canAccess && $0.permissions.canCreateChildren }
                .map { DisplayableTopic(topicId: $0.uuid, name: $0.name) }
            if selectedTopic == nil {
                selectedTopic = Self.resolveDefaultTopic(topicId: defaultTopicId, in: newTopics)
            }
        }.store(in: &storage)

        Publishers.CombineLatest4($text, $images, $poll, $selectedTopic)
            .sink { [unowned self] text, images, poll, selectedTopic in
                hasChanges = Self.hasChanges(text: text, hasImage: !images.isEmpty, hasPoll: poll != nil,
                                             selectedTopicId: selectedTopic?.topicId,
                                             defaultTopicId: defaultTopicId)
            }.store(in: &storage)

        $text
            .removeDuplicates()
            .sink { [unowned self] text in
                if text.count > textMaxLength {
                    textError = .textTooLongError(currentLength: text.count, maxLength: textMaxLength)
                } else {
                    textError = nil
                }
            }.store(in: &storage)

        $images
            .removeDuplicates()
            .receive(on: DispatchQueue.main) // needed because we can reset the pictures
            .sink { [weak self] images in
                guard let self else { return }
                pictureError = nil
                let (kept, hadInvalid) = Self.dropInvalidPictures(images)
                guard hadInvalid else { return }
                alertError = .pictureSelectionError(maxRatio: Validators.Picture.maxRatioStr,
                                                    minSize: Int(Validators.Picture.minSize))
                // Only the invalid pictures are dropped: the other pictures and an attached poll are kept.
                self.images = kept
            }.store(in: &storage)

        $poll
            .removeDuplicates()
            .sink { [weak self] _ in
                // validation is done inside the EditablePoll directly
                self?.pollError = nil
            }.store(in: &storage)
    }

    /// Whether the connected user's only remaining blocker before publishing is the nickname choice
    /// screen — so the consent sheet can be presented *before* it.
    /// Returns `false` when the user is not connected or still owes a (forced) login, since those must
    /// come first.
    private var isBlockedOnlyByFirstPostNicknameValidation: Bool {
        guard case .connected = octopus.core.connectionRepository.connectionState,
              let config = octopus.core.configRepository.communityConfig else { return false }
        let profile = octopus.core.profileRepository.profile
        // A guest still subject to forced login must log in before anything else.
        if profile?.isGuest ?? true, config.forceLoginOnStrongActions { return false }
        return ConnectedActionChecker.needsNicknameValidation(
            for: .post,
            hasConfirmedNickname: profile?.hasConfirmedNickname ?? false,
            nicknameLock: config.profileFieldsLock.nickname,
            isNicknameAppManaged: ConnectedActionChecker.isNicknameAppManaged(
                octopus: octopus, isGuest: profile?.isGuest ?? true))
    }

    /// Sends, keeps or drops the contribution held by `ensureConnected`, depending on the connected profile.
    private func resolvePendingSend(profile: CurrentUserProfile?) {
        guard let pendingSend else { return }
        switch pendingSend.resolution(for: profile.map(PendingSendReason.Profile.init)) {
        case .keepWaiting:
            break
        case .drop:
            self.pendingSend = nil
        case .send:
            self.pendingSend = nil
            DispatchQueue.main.async { [weak self] in
                self?.send()
            }
        }
    }

    /// Called when the member closes the nickname choice screen without confirming their nickname: the
    /// contribution it held is not sent, now or once the nickname is confirmed later. The draft stays.
    func nicknameChoiceClosed() {
        pendingSend = nil
    }

    func send() {
        guard let topic = selectedTopic else { return }
        let post = WritablePost(
            topicId: topic.topicId,
            // A blank text is sent empty by the repository when the post may omit it.
            text: text,
            images: images.map(\.imageData),
            poll: writablePoll,
            cta: cta
        )
        guard Validators.Post.validate(post: post, textRequired: textRequired) else { return }

        // The nickname choice screen must not appear before the user has
        // accepted the community's legal documents. When the connected user's only remaining blocker
        // before publishing is that screen and explicit consent is still pending, present the consent
        // sheet first; the nickname screen then follows once consent is accepted (on the re-entered
        // `send()`). This front-runs only the nickname step — a required (forced) login still comes
        // first (see `isBlockedOnlyByFirstPostNicknameValidation`).
        if isBlockedOnlyByFirstPostNicknameValidation,
           termsAcceptanceMode.isExplicit, !userHasAcceptedCgu, !explicitConsentGivenThisSession {
            consentSheetLeadsToNicknameChoice = true
            displayConsentSheet = true
            isLoading = false
            return
        }

        guard connectedActionChecker.ensureConnected(action: .post, actionWhenNotConnected: authenticationActionBinding) else {
            pendingSend = .held(isBlockedOnlyByNicknameChoice: isBlockedOnlyByFirstPostNicknameValidation,
                                profileId: ConnectedActionChecker.connectedProfile(octopus: octopus)?.id)
            isLoading = false
            return
        }

        // Explicit consent gate: at the first contribution, an explicit-mode community presents the
        // consent sheet before publishing. Acceptance is recorded (via `hasAcceptedCgu`) in
        // `send(post:)`, so once given it is never asked again. (Reached when the user is not blocked
        // by the nickname screen above — e.g. a confirmed or community-locked nickname.)
        if termsAcceptanceMode.isExplicit, !userHasAcceptedCgu, !explicitConsentGivenThisSession {
            consentSheetLeadsToNicknameChoice = false
            displayConsentSheet = true
            isLoading = false
            return
        }

        isLoading = true

        Task {
            await send(post: post)
            isLoading = false
        }
    }

    /// Called when the user accepts in the consent sheet: re-enters `send()`, which now bypasses the
    /// consent gate and publishes (recording acceptance).
    func acceptConsentAndSend() {
        explicitConsentGivenThisSession = true
        send()
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
                alertError = .unknownError
            }
            // do not send the message if we cannot update the profile
            return
        }
        do {
            let (createdPost, imageDatas) = try await octopus.core.postsRepository.send(
                post, creationSource: creationSource, bridgeShareSignature: bridgeShareSignature)
            // The created images are shown right away from the bytes just sent, without downloading them.
            for (url, imageData) in Self.imagesToCache(sent: imageDatas, in: createdPost.medias) {
                guard let image = UIImage(data: imageData) else { continue }
                try? ImageCache.content.store(ImageAndData(imageData: imageData, image: image), url: url)
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
                            pictureToReveal = Self.pictureToReveal(from: argumentError, in: images)
                        case .poll:
                            pollError = .localizedString(multiErrorLocalizedString)
                        }
                    }
                }
            case let .serverCall(serverError):
                alertError = serverError.displayableMessage
            case .other:
                alertError = .unknownError
            }
        }
    }

    func createPoll() {
        poll = EditablePoll()
    }

    /// The bytes sent for each image of a created post, paired with the URL the server gave that image.
    ///
    /// The i-th image sent is the i-th image of the created post's `medias` (videos skipped): the server keeps the
    /// order of the photos. If the counts ever differ, nothing is returned: which photo is missing is unknown, and
    /// pairing by position would cache bytes under the URL of another photo. The images are then downloaded.
    static func imagesToCache(sent imageDatas: [Data], in medias: [OctopusCore.Media]) -> [(url: URL, imageData: Data)] {
        let images = medias.filter { $0.kind == .image }
        guard images.count == imageDatas.count else { return [] }
        return zip(images, imageDatas).map { (url: $0.url, imageData: $1) }
    }

    /// The id of the picture to reveal when the server refused a post with `errors`: it looks only at the errors
    /// linked to the picture field. `nil` when none of them designates one of `images`.
    static func pictureToReveal(from validation: ValidationErrors<SendPost.Field, SendPost.ErrorDetail>,
                                in images: [ImageAndData]) -> String? {
        pictureToReveal(for: (validation.errors[.linkedToField(.picture)] ?? []).map(\.imageIndex), in: images)
    }

    /// The id of the picture to reveal for errors carrying `imageIndexes`: the first index that designates one of
    /// `images`. `nil` when no error carries a valid index, in which case the strip stays where it is.
    static func pictureToReveal(for imageIndexes: [Int?], in images: [ImageAndData]) -> String? {
        imageIndexes
            .lazy
            .compactMap { $0 }
            .first(where: images.indices.contains)
            .map { images[$0].thumbnailId }
    }

    /// The images a composer opens with: the data that decodes to an image, in order, up to
    /// `Validators.Post.maxImageCount`.
    static func seedImages(from datas: [Data]) -> [ImageAndData] {
        let images = datas.compactMap { data in
            UIImage(data: data).map { ImageAndData(imageData: data, image: $0) }
        }
        return Array(images.prefix(Validators.Post.maxImageCount))
    }

    /// The images of the post once the newly picked ones are added after the current ones, up to
    /// `Validators.Post.maxImageCount`: the picks beyond the limit are dropped.
    static func appending(_ new: [ImageAndData], to current: [ImageAndData]) -> [ImageAndData] {
        Array((current + new).prefix(Validators.Post.maxImageCount))
    }

    /// Splits off the pictures that `Validators.Picture` rejects (side too small or ratio too big), keeping the
    /// order of the others.
    static func dropInvalidPictures(_ images: [ImageAndData]) -> (kept: [ImageAndData], hadInvalid: Bool) {
        let kept = images.filter { Validators.Picture.validate($0.image) == .valid }
        return (kept, kept.count != images.count)
    }

    /// Whether the draft has content (text, image or poll) or a topic other than the default one.
    static func hasChanges(text: String, hasImage: Bool, hasPoll: Bool,
                           selectedTopicId: String?, defaultTopicId: String?) -> Bool {
        !text.isEmpty || hasImage || hasPoll || selectedTopicId != defaultTopicId
    }

    /// Whether the publish button is enabled. A post text has no minimum beyond one visible character, so a
    /// blank text that the post may not omit keeps the button disabled, and any other text enables it.
    static func canSend(text: String, hasImage: Bool, poll: WritablePoll?, textRequired: Bool,
                        isLoading: Bool) -> Bool {
        !isLoading &&
        Validators.Post.validate(text: text, hasPoll: poll != nil, hasImage: hasImage,
                                 textRequired: textRequired, ignoreTooShort: true).isSuccess &&
        Validators.Post.validate(poll: poll)
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
