//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import UIKit
import Octopus
import OctopusCore

@MainActor
class ValidateNicknameViewModel: ObservableObject {
    @Published private(set) var form: NicknameChoiceForm
    @Published var picture: EditProfileViewModel.Picture
    @Published private(set) var isSubmitting = false
    /// An alert about the picked picture: the member picks another one, so it only offers OK.
    @Published private(set) var alertError: DisplayableString?
    /// Confirming the nickname failed: besides trying again, the alert lets the member close the screen without
    /// sending the contribution, so a lasting failure (no network, a server refusing again) does not trap them.
    @Published private(set) var failure: DisplayableString?
    @Published private(set) var dismiss = false

    /// The contribution waiting for the nickname, named by the button.
    let contribution: UserAction
    let canEditPicture: Bool
    /// The stored nickname, which the default avatar takes its color from while another one is typed.
    let avatarColorSeed: String?
    /// The default the community chose for the member, drawn while they have no picture.
    let communityAvatar: DefaultAvatar?

    private let octopus: OctopusSDK
    private let validator: Validators.CurrentUserProfile
    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK, contribution: UserAction) {
        self.octopus = octopus
        self.contribution = contribution
        validator = octopus.core.validators.currentUserProfile

        let profile = octopus.core.profileRepository.profile
        let config = octopus.core.configRepository.communityConfig
        // Read once: a config refresh while the member types must not empty the field.
        form = NicknameChoiceForm(currentNickname: profile?.nickname ?? "",
                                  forceNicknameChoice: config?.forceNicknameChoice ?? false)
        picture = .unchanged(profile?.pictureUrl)
        avatarColorSeed = profile?.nickname
        // While the member has a picture, it is the default they would get once they tap "remove".
        communityAvatar = profile?.editPreviewDefaultAvatar
        canEditPicture = Self.canEditPicture(
            isAppManaged: Self.isPictureAppManaged(octopus: octopus, isGuest: profile?.isGuest ?? true),
            lock: config?.profileFieldsLock.avatar ?? .editable)

        let openedForProfileId = profile?.id
        octopus.core.profileRepository.profilePublisher
            .sink { [unowned self] profile in
                if Self.shouldClose(openedForProfileId: openedForProfileId, profileId: profile?.id,
                                    hasConfirmedNickname: profile?.hasConfirmedNickname ?? false) {
                    dismiss = true
                }
            }.store(in: &storage)

        $picture
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main) // the sink may reset the picture
            .sink { [weak self] picture in
                guard let self else { return }
                form.clearPictureError()
                guard case let .changed(_, image) = picture else { return }
                switch Validators.Picture.validate(image) {
                case .sideTooSmall, .ratioTooBig:
                    // Same key, and same argument types, as the profile editor's.
                    let maxRatio: String = Validators.Picture.maxRatioStr
                    let minSize = Int(Validators.Picture.minSize)
                    alertError = .localizationKey("Picture.Selection.Error_maxRatio:\(maxRatio)_minSize:\(minSize)")
                    self.picture = .unchanged(octopus.core.profileRepository.profile?.pictureUrl)
                case .valid:
                    break
                }
            }.store(in: &storage)
    }

    // Edits are ignored while the update runs: the field keeps the focus (and the keyboard) but not the typing.

    func edit(_ nickname: String) {
        guard !isSubmitting else {
            // The text field already shows the typed text: a refresh puts the unchanged nickname back.
            objectWillChange.send()
            return
        }
        form.edit(nickname)
    }

    func clear() {
        guard !isSubmitting else { return }
        form.clear()
    }

    func pick(suggestion: String) {
        guard !isSubmitting else { return }
        form.pick(suggestion: suggestion)
    }

    func submit() {
        guard form.canSubmit, !isSubmitting else { return }
        let profile = octopus.core.profileRepository.profile
        let currentNickname = profile?.nickname ?? ""
        guard form.validateLocally(currentNickname: currentNickname, validator: validator,
                                   isGuest: profile?.isGuest ?? true) else { return }
        let editableProfile = form.editableProfile(currentNickname: currentNickname, picture: pictureUpdate)

        isSubmitting = true
        Task { [octopus] in
            do {
                // The screen cannot be dismissed: a call stuck on a dead connection would leave the member on a
                // spinner with no way out, so it gives up after a while and offers the failure alert's Close.
                guard let result = try await withDeadline(nanoseconds: Self.confirmationTimeout, operation: {
                    try await octopus.core.profileRepository.updateCurrentUserProfile(with: editableProfile)
                }) else {
                    failure = Self.timeoutFailure
                    isSubmitting = false
                    return
                }
                let (updatedProfile, imageData) = result
                if let imageData, let image = UIImage(data: imageData), let imageUrl = updatedProfile.pictureUrl {
                    try? ImageCache.content.store(ImageAndData(imageData: imageData, image: image), url: imageUrl)
                }
                // The screen only closes on a confirmed nickname: without it, the member would wait forever.
                guard updatedProfile.hasConfirmedNickname else {
                    failure = .localizationKey("Error.Unknown")
                    isSubmitting = false
                    return
                }
                // The screen closes from the profile publisher, once the confirmed profile is stored. The button
                // keeps its spinner until then, so the contribution cannot be confirmed twice.
                return
            } catch let error as UpdateProfile.Error {
                failure = Self.failure(of: error, form: &form)
            } catch {
                // Only reached if the update starts throwing another error type.
                failure = .localizationKey("Error.Unknown")
            }
            // Only reached after a failure: the member can correct and try again.
            isSubmitting = false
        }
    }

    /// How long confirming the nickname may take before the screen gives up on it (30 seconds, a picture included).
    nonisolated static let confirmationTimeout: UInt64 = 30 * 1_000_000_000

    /// What the failure alert says when confirming the nickname takes longer than `confirmationTimeout`. Not the
    /// no-network message: the connection may well be alive, only slow, for instance while a picture uploads.
    nonisolated static var timeoutFailure: DisplayableString { .localizationKey("Error.Unknown") }

    /// What the failure alert says when confirming the nickname fails, or `nil` when the refusal is only shown under
    /// the fields, where the member corrects it.
    nonisolated static func failure(of error: UpdateProfile.Error, form: inout NicknameChoiceForm)
    -> DisplayableString? {
        switch error {
        case let .validation(validationErrors): form.apply(validationErrors)
        case let .serverCall(serverError): serverError.displayableMessage
        case .other: .localizationKey("Error.Unknown")
        }
    }

    private var pictureUpdate: EditableProfile.FieldUpdate<Data?> {
        switch picture {
        case .unchanged: .unchanged
        case let .changed(imageData, _): .updated(imageData)
        case .deleted: .updated(nil)
        }
    }

    private static func isPictureAppManaged(octopus: OctopusSDK, isGuest: Bool) -> Bool {
        guard !isGuest, case let .sso(configuration) = octopus.core.connectionRepository.connectionMode else {
            return false
        }
        return configuration.appManagedFields.contains(.picture)
    }

    /// Whether the edit badge is shown: the picture must be neither managed by the host app nor locked by the
    /// community.
    nonisolated static func canEditPicture(isAppManaged: Bool, lock: ProfileFieldLockState) -> Bool {
        EditProfileViewModel.fieldEditMode(isAppManaged: isAppManaged, lock: lock) == .editInOctopus
    }

    /// Whether the screen closes. It cannot be dismissed, so it closes once the nickname is confirmed (the
    /// contribution then goes), or when the profile it was opened for is gone (the host disconnected the member),
    /// so that nobody is left on it without a way out.
    nonisolated static func shouldClose(openedForProfileId: String?, profileId: String?,
                                        hasConfirmedNickname: Bool) -> Bool {
        guard let profileId, profileId == openedForProfileId else { return true }
        return hasConfirmedNickname
    }
}

extension UserAction {
    /// The label of the nickname choice button: it names the contribution waiting to be sent.
    var nicknameChoiceButtonKey: LocalizedStringKey {
        switch self {
        case .comment: "Content.AggregatedInfo.Comment"
        case .reply: "Content.AggregatedInfo.Answer"
        case .post, .reaction, .vote, .moderation, .blockUser, .viewOwnProfile: "Post.Create.Button"
        }
    }
}
