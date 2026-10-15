//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// What the nickname choice screen shows and sends, kept apart from the SDK so its rules can be tested alone.
struct NicknameChoiceForm {
    /// The text of the field.
    private(set) var nickname: String
    /// The error shown under the field. Typing removes it.
    private(set) var error: DisplayableString?
    /// The error shown under the picture.
    private(set) var pictureError: DisplayableString?
    /// Available nicknames proposed after a taken one. They stay while the member types, even in an emptied field,
    /// and are replaced by the suggestions of the next taken nickname.
    private(set) var suggestions: [String] = []

    /// - Parameters:
    ///   - currentNickname: the profile's nickname, generated for a member who never chose one.
    ///   - forceNicknameChoice: when `true`, the member must type a nickname, so the field starts empty.
    init(currentNickname: String, forceNicknameChoice: Bool) {
        nickname = forceNicknameChoice ? "" : currentNickname
    }

    /// The button only needs a non-empty field: format and availability are checked when it is tapped.
    var canSubmit: Bool { !nickname.isEmpty }
    var showsClearButton: Bool { !nickname.isEmpty }

    mutating func edit(_ text: String) {
        guard text != nickname else { return }
        nickname = text
        error = nil
    }

    /// Empties the field. The proposed nickname is not given back: the member types their own.
    mutating func clear() {
        edit("")
    }

    /// Puts a suggestion in the field without sending it: the member can still change it.
    mutating func pick(suggestion: String) {
        edit(suggestion)
    }

    mutating func clearPictureError() {
        pictureError = nil
    }

    /// Checks the nickname with the profile editor's rules, and shows the error under the field when it fails.
    /// An untouched nickname is not sent, so it is not checked either.
    mutating func validateLocally(currentNickname: String, validator: Validators.CurrentUserProfile,
                                  isGuest: Bool) -> Bool {
        guard nickname != currentNickname else { return true }
        guard case .failure = validator.validate(nickname: nickname, isGuest: isGuest) else { return true }
        let minLength = validator.minNicknameLength
        let maxLength = validator.maxNicknameLength
        error = .localizationKey("Profile.Edit.Error.Nickname_minLength:\(minLength)_maxLength:\(maxLength)")
        return false
    }

    /// The update that confirms the nickname. The nickname is only sent when it changed, so a member who keeps
    /// the proposed one never meets an error.
    /// A picture picked or removed here is confirmed, as in the profile editor: an unconfirmed picture is replaced
    /// by the host app's picture whenever that one changes.
    func editableProfile(currentNickname: String, picture: EditableProfile.FieldUpdate<Data?>) -> EditableProfile {
        let hasConfirmedPicture: EditableProfile.FieldUpdate<Bool>
        switch picture {
        case .unchanged: hasConfirmedPicture = .unchanged
        case .updated: hasConfirmedPicture = .updated(true)
        }
        return EditableProfile(
            nickname: nickname == currentNickname ? .unchanged : .updated(nickname),
            picture: picture,
            hasConfirmedNickname: .updated(true),
            hasConfirmedPicture: hasConfirmedPicture,
            wantNicknameSuggestions: true)
    }

    /// Shows the server's refusal: nickname and picture errors go under their field, and a taken nickname replaces
    /// the suggestions. Returns what must be shown in an alert instead, if anything.
    mutating func apply(_ validation: ValidationErrors<UpdateProfile.Field, UpdateProfile.ErrorDetail>)
    -> DisplayableString? {
        var alertMessages = [String]()
        for (displayKind, errors) in validation.errors {
            let message = errors.map(\.localizedMessage).joined(separator: "\n- ")
            switch displayKind {
            case .linkedToField(.nickname):
                error = .localizedString(message)
                for case let .alreadyTaken(suggestions) in errors.map(\.detail) {
                    self.suggestions = suggestions
                }
            case .linkedToField(.picture):
                pictureError = .localizedString(message)
            case .linkedToField(.bio), .alert:
                alertMessages.append(message)
            }
        }
        return alertMessages.isEmpty ? nil : .localizedString(alertMessages.joined(separator: "\n"))
    }
}
