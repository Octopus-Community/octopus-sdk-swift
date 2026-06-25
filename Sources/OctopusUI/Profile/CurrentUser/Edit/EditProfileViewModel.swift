//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore
import UIKit

@MainActor
class EditProfileViewModel: ObservableObject {
    enum Picture: Equatable {
        case unchanged(URL?)
        case changed(Data, UIImage)
        case deleted
    }

    enum FieldEditConfig {
        case editInOctopus
        case editInApp(() -> Void)
        /// Community-locked (read-only / disabled): the field is not shown in the edit screen (OCT-1487).
        case hidden

        var fieldIsEditable: Bool {
            switch self {
            case .editInApp, .hidden: return false
            case .editInOctopus: return true
            }
        }

        var isHidden: Bool {
            if case .hidden = self { return true } else { return false }
        }

        var callback: (() -> Void)? {
            switch self {
            case .editInApp(let callback): return callback
            case .editInOctopus, .hidden: return nil
            }
        }
    }

    /// Pure per-field edit decision combining the SSO app-managed redirect with the community lock.
    /// `appManagedFields` wins for that field (PRD Q4); otherwise a non-editable lock hides the field.
    enum FieldEditMode: Equatable {
        case editInOctopus
        case editInApp
        case hidden
    }

    nonisolated static func fieldEditMode(isAppManaged: Bool, lock: ProfileFieldLockState) -> FieldEditMode {
        if isAppManaged { return .editInApp }
        return lock == .editable ? .editInOctopus : .hidden
    }

    typealias CoreProfileField = OctopusCore.ConnectionMode.SSOConfiguration.ProfileField

    private static func editConfig(for field: CoreProfileField, isAppManaged: Bool,
                                   lock: ProfileFieldLockState,
                                   modifyUser: ((CoreProfileField) -> Void)?) -> FieldEditConfig {
        switch fieldEditMode(isAppManaged: isAppManaged, lock: lock) {
        case .editInApp:
            if let modifyUser { return .editInApp({ modifyUser(field) }) }
            return .editInOctopus
        case .editInOctopus:
            return .editInOctopus
        case .hidden:
            return .hidden
        }
    }

    @Published private(set) var nicknameEditConfig: FieldEditConfig = .editInOctopus
    @Published private(set) var bioEditConfig: FieldEditConfig = .editInOctopus
    @Published private(set) var pictureEditConfig: FieldEditConfig = .editInOctopus

    @Published private(set) var isLoading = false
    @Published private(set) var dismiss = false
    @Published private(set) var alertError: DisplayableString?
    @Published var nickname = ""
    @Published var bio = ""
    @Published var picture = Picture.unchanged(nil)
    @Published var nicknameForAvatar = ""
    @Published private(set) var nicknameError: DisplayableString?
    @Published private(set) var bioError: DisplayableString?
    @Published private(set) var pictureError: DisplayableString?
    var saveAvailable: Bool { !isLoading && nicknameValid() && bioValid() }
    var hasChanges: Bool { editableProfile != nil }

    var bioMaxLength: Int { validator.maxBioLength }

    let octopus: OctopusSDK
    private let validator: Validators.CurrentUserProfile
    private let preventDismissAfterUpdate: Bool

    private var storage = [AnyCancellable]()
    private var savedProfile: CurrentUserProfile?

    // nil if no changes
    private var editableProfile: EditableProfile? {
        let nicknameUpdate: EditableProfile.FieldUpdate<String> =
            savedProfile?.nickname.nilIfEmpty != nickname.nilIfEmpty ?
            .updated(nickname) : .unchanged
        let bioUpdate: EditableProfile.FieldUpdate<String?> = savedProfile?.bio?.nilIfEmpty != bio.nilIfEmpty ?
            .updated(bio) : .unchanged
        let pictureUpdate: EditableProfile.FieldUpdate<Data?> = switch picture {
        case .unchanged: .unchanged
        case let .changed(imageData, _):
            .updated(imageData)
        case .deleted: .updated(nil)
        }

        if case .unchanged = nicknameUpdate, case .unchanged = bioUpdate, case .unchanged = pictureUpdate {
            return nil
        }

        return EditableProfile(
            nickname: nicknameUpdate,
            bio: bioUpdate,
            picture: pictureUpdate,
            hasConfirmedNickname: .updated(true),
            hasConfirmedBio: .updated(true),
            hasConfirmedPicture: .updated(true)
        )
    }

    // Editable profile used when there is no changes but when the fields have not been confirmed yet. This way,
    // saving the profile will mark the fields as confirmed
    private var fieldsConfirmedProfile: EditableProfile? {
        guard let savedProfile else { return nil }
        guard !savedProfile.hasConfirmedNickname || !savedProfile.hasConfirmedBio || !savedProfile.hasConfirmedPicture
        else {
            return nil
        }

        return EditableProfile(
            hasConfirmedNickname: .updated(true),
            hasConfirmedBio: .updated(true),
            hasConfirmedPicture: .updated(true)
        )
    }

    init(octopus: OctopusSDK, preventDismissAfterUpdate: Bool) {
        self.octopus = octopus
        validator = octopus.core.validators.currentUserProfile
        self.preventDismissAfterUpdate = preventDismissAfterUpdate

        Publishers.CombineLatest(
            octopus.core.profileRepository.profilePublisher.compactMap { $0 },
            octopus.core.configRepository.communityConfigPublisher
        )
        .sink { [unowned self] profile, communityConfig in
            let lock = communityConfig?.profileFieldsLock ?? .allEditable
            var appManagedFields: Set<CoreProfileField> = []
            var modifyUser: ((CoreProfileField) -> Void)?

            if !profile.isGuest, case let .sso(configuration) = octopus.core.connectionRepository.connectionMode {
                appManagedFields = configuration.appManagedFields
                modifyUser = configuration.modifyUser

                // update app managed fields
                savedProfile = profile
                if appManagedFields.contains(.nickname) {
                    nickname = profile.nickname
                    nicknameForAvatar = profile.nickname
                }
                if appManagedFields.contains(.bio) {
                    bio = profile.bio ?? ""
                }
                if appManagedFields.contains(.picture) {
                    picture = .unchanged(profile.pictureUrl)
                }
            }

            nicknameEditConfig = Self.editConfig(
                for: .nickname, isAppManaged: appManagedFields.contains(.nickname),
                lock: lock.nickname, modifyUser: modifyUser)
            bioEditConfig = Self.editConfig(
                for: .bio, isAppManaged: appManagedFields.contains(.bio),
                lock: lock.bio, modifyUser: modifyUser)
            pictureEditConfig = Self.editConfig(
                for: .picture, isAppManaged: appManagedFields.contains(.picture),
                lock: lock.avatar, modifyUser: modifyUser)
        }.store(in: &storage)

        // feed the values with the first profile we get
        octopus.core.profileRepository.profilePublisher
            .compactMap { $0 }
            .first()
            .sink { [unowned self] profile in
                savedProfile = profile
                nickname = profile.nickname
                bio = profile.bio ?? ""
                picture = .unchanged(profile.pictureUrl)
                nicknameForAvatar = profile.nickname
            }.store(in: &storage)

        // observe connection state to dismiss screen if incorrect state
        octopus.core.profileRepository.profilePublisher
            .sink { [unowned self] in
                if $0 == nil {
                    dismiss = true
                }
        }.store(in: &storage)

        $nickname
            .removeDuplicates()
            .dropFirst()
            .sink { [unowned self] nickname in
                switch validator.validate(nickname: nickname,
                                          isGuest: octopus.core.profileRepository.profile?.isGuest ?? true) {
                case let .failure(error):
                    switch error {
                    case .tooShort, .tooLong:
                        nicknameError = .localizationKey(
                            "Profile.Edit.Error.Nickname_minLength:\(validator.minNicknameLength)_maxLength:\(validator.maxNicknameLength)")
                    }
                case .success:
                    nicknameError = nil
                }
            }.store(in: &storage)

        $bio
            .removeDuplicates()
            .sink { [unowned self] bio in
                switch validator.validate(bio: bio,
                                          isGuest: octopus.core.profileRepository.profile?.isGuest ?? true) {
                case let .failure(error):
                    switch error {
                    case .tooLong:
                        bioError = .localizationKey("Error.Text.TooLong_currentLength:\(bio.count)_maxLength:\(bioMaxLength)")
                    }
                case .success:
                    bioError = nil
                }
            }.store(in: &storage)

        $picture
            .removeDuplicates()
            .receive(on: DispatchQueue.main) // needed because we can reset the picture
            .sink { [weak self] picture in
                guard let self else { return }
                switch picture {
                case let .changed(_, image):
                    switch Validators.Picture.validate(image) {
                    case .sideTooSmall, .ratioTooBig:
                        alertError = .localizationKey(
                            "Picture.Selection.Error_maxRatio:\(Validators.Picture.maxRatioStr)_minSize:\(Int(Validators.Picture.minSize))")
                        self.picture = .unchanged(savedProfile?.pictureUrl)
                    case .valid:
                        break
                    }
                case .deleted:
                    nicknameForAvatar = nickname
                case .unchanged:
                    break
                }
                pictureError = nil
            }.store(in: &storage)

        $picture
            .sink { [unowned self] picture in
                if case .deleted = picture {
                    nicknameForAvatar = nickname
                }
                pictureError = nil
            }.store(in: &storage)
    }

    func updateProfile() {
        guard saveAvailable else { return }
        guard let editableProfile = editableProfile ?? fieldsConfirmedProfile else {
            dismiss = true
            return
        }

        Task { [octopus] in
            isLoading = true
            do {
                let (profile, imageData) = try await octopus.core.profileRepository
                    .updateCurrentUserProfile(with: editableProfile)
                if let imageData, let image = UIImage(data: imageData), let imageUrl = profile.pictureUrl {
                    try? ImageCache.content.store(ImageAndData(imageData: imageData, image: image), url: imageUrl)
                }
                if !preventDismissAfterUpdate {
                    dismiss = true
                }
            } catch let error as UpdateProfile.Error {
                switch error {
                case let .validation(argumentError):
                    for (displayKind, errors) in argumentError.errors {
                        let multiErrorLocalizedString = errors.map(\.localizedMessage).joined(separator: "\n- ")
                        switch displayKind {
                        case .alert:
                            alertError = .localizedString(multiErrorLocalizedString)
                        case let .linkedToField(field):
                            switch field {
                            case .nickname:
                                nicknameError = .localizedString(multiErrorLocalizedString)
                            case .bio:
                                bioError = .localizedString(multiErrorLocalizedString)
                            case .picture:
                                pictureError = .localizedString(multiErrorLocalizedString)
                            }
                        }
                    }
                case let .serverCall(serverError):
                    alertError = serverError.displayableMessage
                case .other:
                    alertError = .localizationKey("Error.Unknown")
                }
            }
            isLoading = false
        }
    }

    private func nicknameValid() -> Bool {
        guard case .success = validator.validate(
            nickname: nickname, isGuest: octopus.core.profileRepository.profile?.isGuest ?? true) else { return false }
        return true
    }

    private func bioValid() -> Bool {
        guard case .success = validator.validate(
            bio: bio, isGuest: octopus.core.profileRepository.profile?.isGuest ?? true) else { return false }
        return true
    }
}
