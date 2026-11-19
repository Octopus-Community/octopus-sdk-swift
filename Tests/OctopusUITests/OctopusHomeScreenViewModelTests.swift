//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Testing
@testable import OctopusCore
@testable import OctopusUI

/// The access denied screen stands at the root of the community. An access taken away while the user is deeper
/// (a post, a profile) brings them back to it, instead of leaving them on a screen whose every call is refused.
@MainActor
struct OctopusHomeScreenViewModelTests {
    private let userConfig = CurrentValueSubject<UserConfig?, Never>(
        UserConfig(canAccessCommunity: true, accessDeniedMessage: nil))

    @Test func aDeniedAccessBringsBackToTheRoot() {
        let viewModel = makeViewModel()
        viewModel.mainFlowPath.path = [.currentUserProfile, .editProfile(bioFocused: false, pictureFocused: false)]
        viewModel.mainFlowPath.reportTarget = .profile(profileId: "profileId", blockableProfileId: nil)

        userConfig.send(UserConfig(canAccessCommunity: false, accessDeniedMessage: nil,
                                   noAccessReason: .memberExcluded))

        #expect(viewModel.displayCommunityAccessDenied)
        #expect(viewModel.mainFlowPath.path.isEmpty)
        #expect(viewModel.mainFlowPath.reportTarget == nil)
    }

    /// Emptying the path was seen not to be enough on a device. The whole stack is built again, which the view does
    /// when this identifier changes.
    @Test func aDeniedAccessAsksForANewNavigationStack() {
        let viewModel = makeViewModel()
        let stackId = viewModel.navigationStackId

        userConfig.send(UserConfig(canAccessCommunity: false, accessDeniedMessage: nil))

        #expect(viewModel.navigationStackId != stackId)
    }

    /// The access denied screen reads the access again by itself: a stack built again each time would create it
    /// again, and read again, without end.
    @Test func anAccessStillDeniedKeepsTheNavigationStack() {
        let viewModel = makeViewModel()
        userConfig.send(UserConfig(canAccessCommunity: false, accessDeniedMessage: nil))
        let stackId = viewModel.navigationStackId

        userConfig.send(UserConfig(canAccessCommunity: false, accessDeniedMessage: "Bye",
                                   noAccessReason: .memberExcluded))

        #expect(viewModel.navigationStackId == stackId)
    }

    @Test func aGrantedAccessKeepsTheNavigationStack() {
        let viewModel = makeViewModel()
        let stackId = viewModel.navigationStackId

        userConfig.send(UserConfig(canAccessCommunity: true, accessDeniedMessage: nil))
        userConfig.send(nil)

        #expect(viewModel.navigationStackId == stackId)
    }

    @Test func aGrantedAccessLeavesTheUserWhereTheyAre() {
        let viewModel = makeViewModel()
        viewModel.mainFlowPath.path = [.currentUserProfile]

        userConfig.send(UserConfig(canAccessCommunity: true, accessDeniedMessage: nil))

        #expect(!viewModel.displayCommunityAccessDenied)
        #expect(viewModel.mainFlowPath.path == [.currentUserProfile])
    }

    /// Not read yet: nothing says the access is denied.
    @Test func anUnknownAccessLeavesTheUserWhereTheyAre() {
        let viewModel = makeViewModel()
        viewModel.mainFlowPath.path = [.currentUserProfile]

        userConfig.send(nil)

        #expect(!viewModel.displayCommunityAccessDenied)
        #expect(viewModel.mainFlowPath.path == [.currentUserProfile])
    }

    @Test func theCommunityComesBackWithTheAccess() {
        let viewModel = makeViewModel()
        userConfig.send(UserConfig(canAccessCommunity: false, accessDeniedMessage: nil))

        userConfig.send(UserConfig(canAccessCommunity: true, accessDeniedMessage: nil))

        #expect(!viewModel.displayCommunityAccessDenied)
    }

    private func makeViewModel() -> OctopusHomeScreenViewModel {
        OctopusHomeScreenViewModel(userConfigPublisher: userConfig.eraseToAnyPublisher(),
                                   overridenLocalePublisher: Just(nil).eraseToAnyPublisher())
    }
}
