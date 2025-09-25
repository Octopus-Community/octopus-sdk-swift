//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import OctopusCore

struct MainFlowNavigationStack<RootView: View>: View {
    let octopus: OctopusSDK
    let bottomSafeAreaInset: CGFloat
    @Compat.StateObject private var mainFlowPath: MainFlowPath
    @ViewBuilder let rootView: RootView

    @State private var keyboardHeight = CGFloat.zero
    @State private var bottomInset: CGFloat

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, bottomSafeAreaInset: CGFloat = 0,
         @ViewBuilder _ rootView: () -> RootView) {
        self.octopus = octopus
        _mainFlowPath = Compat.StateObject(wrappedValue: mainFlowPath)
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.rootView = rootView()
        self._bottomInset = .init(initialValue: bottomSafeAreaInset)
    }

    var body: some View {
        NBNavigationStack(path: $mainFlowPath.path) {
            rootView
                .nbNavigationDestination(for: MainFlowScreen.self) { screen in
                    Group {
                        switch screen {
                        case .currentUserProfile:
                            CurrentUserProfileSummaryView(octopus: octopus, mainFlowPath: mainFlowPath)
                        case let .publicProfile(profileId):
                            ProfileSummaryView(octopus: octopus, profileId: profileId)
                        case let .createPost(withPoll):
                            CreatePostView(octopus: octopus, withPoll: withPoll)
                        case let .postDetail(postId, comment, commentToScrollTo, scrollToMostRecentComment, origin, hasFeaturedComment):
                            PostDetailView(octopus: octopus, mainFlowPath: mainFlowPath, postUuid: postId,
                                           comment: comment,
                                           commentToScrollTo: commentToScrollTo,
                                           scrollToMostRecentComment: scrollToMostRecentComment,
                                           origin: origin,
                                           hasFeaturedComment: hasFeaturedComment)
                        case let .commentDetail(commentId, displayGoToParentButton, reply, replyToScrollTo):
                            CommentDetailView(octopus: octopus, commentUuid: commentId,
                                              displayGoToParentButton: displayGoToParentButton,
                                              reply: reply, replyToScrollTo: replyToScrollTo)
                        case let .reportContent(contentId):
                            ReportView(octopus: octopus, context: .content(contentId: contentId))
                        case let .reportProfile(profileId):
                            ReportView(octopus: octopus, context: .profile(profileId: profileId))
                        case let .editProfile(bioFocused, pictureFocused):
                            EditProfileView(octopus: octopus, bioFocused: bioFocused, photoPickerFocused: pictureFocused)
                        case .settingsList:
                            SettingsListView(octopus: octopus, mainFlowPath: mainFlowPath)
                        case .settingsAccount:
                            SettingProfileView(octopus: octopus)
                        case .settingsAbout:
                            SettingsAboutView(octopus: octopus)
                        case .settingsHelp:
                            SettingsHelpView(octopus: octopus)
                        case .reportExplanation:
                            SignalExplanationView(octopus: octopus)
                        case .deleteAccount:
                            DeleteAccountView(octopus: octopus, mainFlowPath: mainFlowPath)
                        }
                    }
                    .insetableMainNavigationView(bottomSafeAreaInset: bottomSafeAreaInset)
                }

        }
        // TODO Djavan remove this as it forces to use navigationView instead of navigationStack. It has been set
        // because of a bug impacting the CreatePostView that was re-created when put in background.
        .nbUseNavigationStack(.never)
    }
}
