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

    private var storage = [AnyCancellable]()
    private var savedProfile: CurrentUserProfile?

    // nil if no changes
    private var editableProfile: EditableProfile? {
        guard saveAvailable else { return nil }

        let nicknameUpdate: EditableProfile.FieldUpdate<String> =
            savedProfile?.nickname.nilIfEmpty != nickname.nilIfEmpty ?
            .updated(nickname) : .notUpdated
        let bioUpdate: EditableProfile.FieldUpdate<String?> = savedProfile?.bio?.nilIfEmpty != bio.nilIfEmpty ?
            .updated(bio) : .notUpdated
        let pictureUpdate: EditableProfile.FieldUpdate<Data?> = switch picture {
        case .unchanged: .notUpdated
        case let .changed(imageData, _):
            .updated(imageData)
        case .deleted: .updated(nil)
        }

        if case .notUpdated = nicknameUpdate, case .notUpdated = bioUpdate, case .notUpdated = pictureUpdate {
            return nil
        }

        return EditableProfile(
            nickname: nicknameUpdate,
            bio: bioUpdate,
            picture: pictureUpdate)
    }

    init(octopus: OctopusSDK) {
        self.octopus = octopus
        validator = octopus.core.validators.currentUserProfile

        // feed the values with the first profile we get
        octopus.core.profileRepository.$profile
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
        octopus.core.profileRepository.$profile
            .sink { [unowned self] in
                if $0 == nil {
                    dismiss = true
                }
        }.store(in: &storage)

        $nickname
            .removeDuplicates()
            .dropFirst()
            .sink { [unowned self] nickname in
                switch validator.validate(nickname: nickname) {
                case let .failure(error):
                    switch error {
                    case .tooShort, .tooLong:
                        nicknameError = .localizationKey(
                            "Profile.Create.Error.Nickname_minLength:\(validator.minNicknameLength)_maxLength:\(validator.maxNicknameLength)")
                    }
                case .success:
                    nicknameError = nil
                }
            }.store(in: &storage)

        $bio
            .removeDuplicates()
            .sink { [unowned self] bio in
                switch validator.validate(bio: bio) {
                case let .failure(error):
                    switch error {
                    case .tooLong:
                        bioError = .localizationKey("Error.TextTooLong_currentLength:\(bio.count)_maxLength:\(bioMaxLength)")
                    }
                case .success:
                    bioError = nil
                }
            }.store(in: &storage)

        $picture
            .removeDuplicates()
            .receive(on: DispatchQueue.main) // needed because we can reset the picture
            .sink { [unowned self] picture in
                switch picture {
                case let .changed(_, image):
                    let validator = octopus.core.validators.picture
                    switch validator.validate(image) {
                    case .sideTooSmall, .ratioTooBig:
                        alertError = .localizationKey("Picture.Selection.Error_maxRatio:\(validator.maxRatioStr)_minSize:\(Int(validator.minSize))")
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
        guard let editableProfile else {
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
                dismiss = true
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
                }
            }
            isLoading = false
        }
    }

    private func nicknameValid() -> Bool {
        guard case .success = validator.validate(nickname: nickname) else { return false }
        return true
    }

    private func bioValid() -> Bool {
        guard case .success = validator.validate(bio: bio) else { return false }
        return true
    }
}
