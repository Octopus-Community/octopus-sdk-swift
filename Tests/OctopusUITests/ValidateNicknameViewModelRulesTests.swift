//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import SwiftUI
@testable import OctopusUI
@testable import OctopusCore

/// The rules of the nickname choice screen that live on its view model, checked without an `OctopusSDK`.
struct ValidateNicknameViewModelRulesTests {

    // MARK: Button label

    @Test func buttonNamesTheWaitingContribution() {
        #expect(UserAction.post.nicknameChoiceButtonKey == LocalizedStringKey("Post.Create.Button"))
        #expect(UserAction.comment.nicknameChoiceButtonKey == LocalizedStringKey("Content.AggregatedInfo.Comment"))
        #expect(UserAction.reply.nicknameChoiceButtonKey == LocalizedStringKey("Content.AggregatedInfo.Answer"))
    }

    @Test func buttonFallsBackOnPublishForOtherActions() {
        #expect(UserAction.reaction.nicknameChoiceButtonKey == LocalizedStringKey("Post.Create.Button"))
    }

    // MARK: Closing

    @Test func staysOpenUntilTheNicknameIsConfirmed() {
        #expect(!ValidateNicknameViewModel.shouldClose(openedForProfileId: "p1", profileId: "p1",
                                                       hasConfirmedNickname: false))
        #expect(ValidateNicknameViewModel.shouldClose(openedForProfileId: "p1", profileId: "p1",
                                                      hasConfirmedNickname: true))
    }

    @Test func closesWhenTheProfileIsGone() {
        #expect(ValidateNicknameViewModel.shouldClose(openedForProfileId: "p1", profileId: nil,
                                                      hasConfirmedNickname: false))
    }

    @Test func closesWhenAnotherMemberIsConnected() {
        #expect(ValidateNicknameViewModel.shouldClose(openedForProfileId: "p1", profileId: "p2",
                                                      hasConfirmedNickname: false))
    }

    @Test func closesWhenOpenedWithoutProfile() {
        #expect(ValidateNicknameViewModel.shouldClose(openedForProfileId: nil, profileId: "p1",
                                                      hasConfirmedNickname: false))
    }

    // MARK: Failure alert

    private typealias Errors = ValidationErrors<UpdateProfile.Field, UpdateProfile.ErrorDetail>

    private func form() -> NicknameChoiceForm {
        NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: true)
    }

    @Test func networkFailureOffersTheWayOut() {
        var form = form()
        #expect(ValidateNicknameViewModel.failure(of: .serverCall(.noNetwork), form: &form)
                == .localizationKey("Error.NoNetwork"))
    }

    @Test func timeoutIsNotReportedAsANetworkOutage() {
        #expect(ValidateNicknameViewModel.timeoutFailure == .localizationKey("Error.Unknown"))
    }

    @Test func unknownFailureOffersTheWayOut() {
        var form = form()
        #expect(ValidateNicknameViewModel.failure(of: .other(nil), form: &form) == .localizationKey("Error.Unknown"))
    }

    @Test func refusalNotLinkedToTheFieldsOffersTheWayOut() {
        var form = form()
        let error = UpdateProfile.Error.validation(Errors(errors: [
            .alert: [.init(localizedMessage: "Oops", detail: .unknown)]]))

        #expect(ValidateNicknameViewModel.failure(of: error, form: &form) == .localizedString("Oops"))
    }

    /// A refused nickname is corrected in the field: no alert, so no way out offered.
    @Test func nicknameRefusalStaysUnderTheField() {
        var form = form()
        form.edit("Marine")
        let error = UpdateProfile.Error.validation(Errors(errors: [
            .linkedToField(.nickname): [.init(localizedMessage: "Already taken",
                                              detail: .alreadyTaken(suggestions: ["Marine_7"]))]]))

        #expect(ValidateNicknameViewModel.failure(of: error, form: &form) == nil)
        #expect(form.error == .localizedString("Already taken"))
        #expect(form.suggestions == ["Marine_7"])
    }

    // MARK: Picture badge

    @Test func pictureIsEditableOnlyWhenNeitherHostManagedNorLocked() {
        #expect(ValidateNicknameViewModel.canEditPicture(isAppManaged: false, lock: .editable))
        #expect(!ValidateNicknameViewModel.canEditPicture(isAppManaged: true, lock: .editable))
        #expect(!ValidateNicknameViewModel.canEditPicture(isAppManaged: false, lock: .readOnly))
        #expect(!ValidateNicknameViewModel.canEditPicture(isAppManaged: false, lock: .disabled))
    }
}
