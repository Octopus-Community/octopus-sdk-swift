//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import Foundation
@testable import OctopusUI
@testable import OctopusCore

/// The rules of the nickname choice screen, checked without an `OctopusSDK`.
struct NicknameChoiceFormTests {
    private typealias Errors = ValidationErrors<UpdateProfile.Field, UpdateProfile.ErrorDetail>

    private let validator = Validators.CurrentUserProfile(appManagedFields: [])

    private func errors(_ dict: [Errors.DisplayKind: [Errors.Error]]) -> Errors { Errors(errors: dict) }

    // MARK: Opening

    @Test func forcedChoiceStartsEmpty() {
        let form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)
        #expect(form.nickname.isEmpty)
        #expect(!form.canSubmit)
        #expect(!form.showsClearButton)
    }

    @Test func unforcedChoiceStartsWithTheCurrentNickname() {
        let form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: false)
        #expect(form.nickname == "user-2ab2")
        #expect(form.canSubmit)
        #expect(form.showsClearButton)
    }

    // MARK: Editing

    @Test func typingRemovesTheErrorAndKeepsTheSuggestions() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)
        form.edit("Marine")
        _ = form.apply(errors([.linkedToField(.nickname): [
            .init(localizedMessage: "Already taken", detail: .alreadyTaken(suggestions: ["Marine_7"]))]]))

        form.edit("Marin")

        #expect(form.error == nil)
        #expect(form.suggestions == ["Marine_7"])
    }

    @Test func clearingNeverGivesBackTheProposedNickname() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: false)

        form.clear()

        #expect(form.nickname.isEmpty)
        #expect(!form.canSubmit)
    }

    @Test func pickingASuggestionReplacesTheTextAndRemovesTheError() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)
        form.edit("Marine")
        _ = form.apply(errors([.linkedToField(.nickname): [
            .init(localizedMessage: "Already taken", detail: .alreadyTaken(suggestions: ["Marine_7"]))]]))

        form.pick(suggestion: "Marine_7")

        #expect(form.nickname == "Marine_7")
        #expect(form.error == nil)
        #expect(form.suggestions == ["Marine_7"])
    }

    // MARK: Local check

    @Test func tooShortNicknameIsRefusedLocally() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)
        form.edit("Be")

        let isValid = form.validateLocally(currentNickname: "user-2ab2", validator: validator, isGuest: true)

        // `LocalizedStringKey` is not reliably comparable once it has interpolations: compare the key it resolves to.
        guard case let .localizationKey(key)? = form.error else {
            Issue.record("Expected a localization key under the field")
            return
        }
        #expect(!isValid)
        #expect(key.stringKey == "Profile.Edit.Error.Nickname_minLength:%lld_maxLength:%lld")
    }

    @Test func validNicknameIsAccepted() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)
        form.edit("Benoit")

        let isValid = form.validateLocally(currentNickname: "user-2ab2", validator: validator, isGuest: true)

        #expect(isValid)
        #expect(form.error == nil)
    }

    @Test func untouchedNicknameIsNotChecked() {
        // Not sent, so not checked: a nickname set by the host app may be longer than the editor allows.
        let longNickname = String(repeating: "a", count: 30)
        var form = NicknameChoiceForm(currentNickname: longNickname, forceNicknameChoice: false)

        let isValid = form.validateLocally(currentNickname: longNickname, validator: validator, isGuest: true)

        #expect(isValid)
    }

    // MARK: Update sent

    @Test func untouchedNicknameIsNotSent() {
        let form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: false)

        let profile = form.editableProfile(currentNickname: "user-2ab2", picture: .unchanged)

        guard case .unchanged = profile.nickname else {
            Issue.record("Expected an unchanged nickname")
            return
        }
        guard case .updated(true) = profile.hasConfirmedNickname else {
            Issue.record("Expected the nickname to be confirmed")
            return
        }
        #expect(profile.wantNicknameSuggestions)
        guard case .unchanged = profile.picture else {
            Issue.record("Expected an unchanged picture")
            return
        }
        // An untouched picture stays unconfirmed: the host app's picture keeps replacing it.
        guard case .unchanged = profile.hasConfirmedPicture else {
            Issue.record("Expected the picture not to be confirmed")
            return
        }
    }

    @Test func changedNicknameIsSentWithThePicture() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)
        form.edit("Benoit")
        let pictureData = Data([1, 2, 3])

        let profile = form.editableProfile(currentNickname: "user-2ab2", picture: .updated(pictureData))

        guard case .updated("Benoit") = profile.nickname else {
            Issue.record("Expected the typed nickname")
            return
        }
        guard case let .updated(sentPicture) = profile.picture, sentPicture == pictureData else {
            Issue.record("Expected the picked picture")
            return
        }
        // Confirmed like in the profile editor, so the host app's picture no longer replaces it.
        guard case .updated(true) = profile.hasConfirmedPicture else {
            Issue.record("Expected the picked picture to be confirmed")
            return
        }
    }

    @Test func removedPictureIsConfirmed() {
        let form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: false)

        let profile = form.editableProfile(currentNickname: "user-2ab2", picture: .updated(nil))

        guard case .updated(nil) = profile.picture else {
            Issue.record("Expected the picture to be removed")
            return
        }
        guard case .updated(true) = profile.hasConfirmedPicture else {
            Issue.record("Expected the removal to be confirmed")
            return
        }
    }

    // MARK: Server refusal

    @Test func takenNicknameShowsTheErrorAndReplacesTheSuggestions() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)
        form.edit("Marine")
        _ = form.apply(errors([.linkedToField(.nickname): [
            .init(localizedMessage: "Already taken", detail: .alreadyTaken(suggestions: ["Marine_7"]))]]))

        let alert = form.apply(errors([.linkedToField(.nickname): [
            .init(localizedMessage: "Already taken",
                  detail: .alreadyTaken(suggestions: ["Benoit.23", "Benoit_2f"]))]]))

        #expect(alert == nil)
        #expect(form.error == .localizedString("Already taken"))
        #expect(form.suggestions == ["Benoit.23", "Benoit_2f"])
    }

    @Test func takenNicknameWithoutSuggestionsShowsTheErrorAlone() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)
        _ = form.apply(errors([.linkedToField(.nickname): [
            .init(localizedMessage: "Already taken", detail: .alreadyTaken(suggestions: ["Marine_7"]))]]))

        _ = form.apply(errors([.linkedToField(.nickname): [
            .init(localizedMessage: "Already taken", detail: .alreadyTaken(suggestions: []))]]))

        #expect(form.suggestions.isEmpty)
        #expect(form.error == .localizedString("Already taken"))
    }

    @Test func otherNicknameErrorKeepsTheSuggestions() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)
        _ = form.apply(errors([.linkedToField(.nickname): [
            .init(localizedMessage: "Already taken", detail: .alreadyTaken(suggestions: ["Marine_7"]))]]))

        _ = form.apply(errors([.linkedToField(.nickname): [
            .init(localizedMessage: "Forbidden word", detail: .bannedWordUsed(["word"]))]]))

        #expect(form.error == .localizedString("Forbidden word"))
        #expect(form.suggestions == ["Marine_7"])
    }

    @Test func bioErrorIsAnAlert() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)

        let alert = form.apply(errors([.linkedToField(.bio): [
            .init(localizedMessage: "Bio refused", detail: .moderatedContent)]]))

        #expect(alert == .localizedString("Bio refused"))
        #expect(form.error == nil)
    }

    @Test func retypingTheSameTextKeepsTheError() {
        // A SwiftUI binding may send the current value again: it is not an edit.
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)
        form.edit("Marine")
        _ = form.apply(errors([.linkedToField(.nickname): [
            .init(localizedMessage: "Already taken", detail: .alreadyTaken(suggestions: ["Marine_7"]))]]))

        form.edit("Marine")

        #expect(form.error == .localizedString("Already taken"))
    }

    @Test func pictureErrorGoesUnderThePicture() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)

        let alert = form.apply(errors([.linkedToField(.picture): [
            .init(localizedMessage: "Bad picture", detail: .badFileFormat)]]))

        #expect(alert == nil)
        #expect(form.pictureError == .localizedString("Bad picture"))
        form.clearPictureError()
        #expect(form.pictureError == nil)
    }

    @Test func errorNotLinkedToAFieldIsAnAlert() {
        var form = NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)

        let alert = form.apply(errors([.alert: [.init(localizedMessage: "Oops", detail: .unknown)]]))

        #expect(alert == .localizedString("Oops"))
        #expect(form.error == nil)
    }
}
