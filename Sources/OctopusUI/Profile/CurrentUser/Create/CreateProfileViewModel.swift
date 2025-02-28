//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class CreateProfileViewModel: ObservableObject {

    enum State {
        case pendingUserInput
        case loading
    }

    @Published private(set) var isLoading = false
    @Published private(set) var dismiss = false
    @Published private(set) var isLoggedIn = false
    @Published private(set) var alertError: DisplayableString?
    @Published var nickname = ""
    @Published var birthDate: Date
    @Published private(set) var nicknameError: DisplayableString?
    @Published private(set) var birthDateError: DisplayableString?

    @Published private(set) var canEditNickname = true
    @Published private(set) var ageInformation: OctopusCore.ClientUserProfile.AgeInformation? // TODO: Djavan use an inner type

    private var nicknameHasBeenValidOnce = false

    var buttonAvailable: Bool { nicknameValid() && birthDateValid() }

    let birthDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        return dateFormatter
    }()

    let octopus: OctopusSDK
    private let validator: Validators.CurrentUserProfile

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus
        validator = octopus.core.validators.currentUserProfile
        let calendar = Calendar(identifier: .gregorian)
        let currentYear = calendar.dateComponents([.year], from: Date()).year!
        let components = DateComponents(year: currentYear, month: 6, day: 15)
        birthDate = calendar.date(from: components)!

        octopus.core.connectionRepository.connectionStatePublisher.sink { [unowned self] in
            switch $0 {
            case let .profileCreationRequired(defaultProfile, lockedFields):
                if let defaultNickname = defaultProfile.nickname {
                    nickname = defaultNickname
                    canEditNickname = !(lockedFields?.contains(.nickname) ?? false)
                }
                ageInformation = defaultProfile.ageInformation
            case .connected:        isLoggedIn = true
            default:                dismiss = true
            }
        }.store(in: &storage)

        $birthDate
            .removeDuplicates()
            .dropFirst()
            .sink { [unowned self] birthDate in
                switch validator.validate(birthDate: birthDate) {
                case .failure:
                    birthDateError = .localizationKey(
                        "Profile.Create.Error.TooYoung_minAge:\(validator.minAge)")
                case .success:
                    birthDateError = nil
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
                        if nicknameHasBeenValidOnce {
                            nicknameError = .localizationKey(
                                "Profile.Create.Error.Nickname_minLength:\(validator.minNicknameLength)_maxLength:\(validator.maxNicknameLength)")
                        }
                    }
                case .success:
                    nicknameHasBeenValidOnce = true
                    nicknameError = nil
                }
            }.store(in: &storage)
    }

    func createProfile() {
        if ageInformation != .legalAgeReached {
            guard case .success = validator.validate(birthDate: birthDate) else {
                birthDateError = .localizationKey(
                    "Profile.Create.Error.TooYoung_minAge:\(validator.minAge)")
                return
            }
        }
        guard nicknameValid() else { return }

        let bio: EditableProfile.FieldUpdate<String?>
        let picture: EditableProfile.FieldUpdate<Data?>
        if case let .profileCreationRequired(defaultValues, _) = octopus.core.connectionRepository.connectionState {
            if let defaultBio = defaultValues.bio {
                bio = .updated(defaultBio)
            } else {
                bio = .notUpdated
            }
            if let defaultPicture = defaultValues.picture {
                picture = .updated(defaultPicture)
            } else {
                picture = .notUpdated
            }
        } else {
            bio = .notUpdated
            picture = .notUpdated
        }

        Task { [octopus] in
            isLoading = true
            do {
                try await octopus.core.profileRepository.updateCurrentUserProfile(
                    with: .init(nickname: .updated(nickname), bio: bio, picture: picture))
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
                            default:
                                // we only edit nickname, if another field is in error, display it as an alert
                                alertError = .localizedString(multiErrorLocalizedString)
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
        guard canEditNickname else { return true } // no validation if nickname is synchronized
        guard case .success = validator.validate(nickname: nickname) else { return false }
        return true
    }

    private func birthDateValid() -> Bool {
        guard ageInformation != .legalAgeReached else { return true } // no validation if age has already been checked by the app
        guard ageInformation != .underaged else { return false } // fail any attempt to create a profile when underaged
        guard case .success = validator.validate(birthDate: birthDate) else { return false }
        return true
    }
}
