//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct ProfileSummaryView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @EnvironmentObject var trackingApi: TrackingApi
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: ProfileSummaryViewModel

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var displayBlockUserAlert = false

    @State private var openActions = false

    @State private var noConnectedReplacementAction: ConnectedActionReplacement?

    @State private var zoomableImageInfo: ZoomableImageInfo?

    init(octopus: OctopusSDK, translationStore: ContentTranslationPreferenceStore, profileId: String) {
        _viewModel = Compat.StateObject(wrappedValue: ProfileSummaryViewModel(
            octopus: octopus, translationStore: translationStore, profileId: profileId))
    }

    var body: some View {
        VStack {
            ContentView(profile: viewModel.profile,
                        displayAccountAge: viewModel.displayAccountAge,
                        zoomableImageInfo: $zoomableImageInfo, refresh: viewModel.refresh) {
                if let postFeedViewModel = viewModel.postFeedViewModel {
                    PostFeedView(
                        viewModel: postFeedViewModel,
                        zoomableImageInfo: $zoomableImageInfo,
                        displayPostDetail: {
                            if !$1 && !$2 && $3 == nil {
                                trackingApi.emit(event: .postClicked(.init(postId: $0, coreSource: .profile)))
                            }
                            navigator.push(.postDetail(postId: $0, comment: $1, commentToScrollTo: $3,
                                                       scrollToMostRecentComment: $2, origin: .sdk,
                                                       hasFeaturedComment: $4))
                        },
                        displayCommentDetail: {
                            navigator.push(.commentDetail(
                                commentId: $0, displayGoToParentButton: false, reply: $1, replyToScrollTo: nil))
                        },
                        displayProfile: { _ in },
                        displayContentModeration: {
                            navigator.push(.reportContent(contentId: $0))
                        }) {
                            OtherUserEmptyPostView()
                        }
                } else {
                    EmptyView()
                }
            }
        }
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem)
        .toastContainer(octopus: viewModel.octopus)
        .compatAlert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
        .emitScreenDisplayed(.otherUserProfile(.init(profileId: viewModel.profileId)), trackingApi: trackingApi)
        .onReceive(viewModel.$error) { error in
            guard let error else { return }
            displayableError = error
            displayError = true
        }
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            presentationMode.wrappedValue.dismiss()
        }
        .actionSheet(isPresented: $openActions) {
            ActionSheet(title: Text("ActionSheet.Title", bundle: .module), buttons: [
                ActionSheet.Button.destructive(Text("Moderation.Profile.Button", bundle: .module)) {
                    guard viewModel.ensureConnected(action: .moderation) else { return }
                    navigator.push(.reportProfile(profileId: viewModel.profileId))
                },
                ActionSheet.Button.destructive(Text("Block.Profile.Button", bundle: .module)) {
                    guard viewModel.ensureConnected(action: .blockUser) else { return }
                    displayBlockUserAlert = true
                },
                .cancel()
            ])
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Block.Profile.Alert.Title", bundle: .module),
                    isPresented: $displayBlockUserAlert, actions: {
                        Button(role: .cancel, action: {}, label: { Text("Common.Cancel", bundle: .module) })
                        Button(role: .destructive, action: viewModel.blockUser,
                               label: { Text("Common.Continue", bundle: .module) })
                    }, message: {
                        Text("Block.Profile.Alert.Message", bundle: .module)
                    })
            } else {
                $0.alert(isPresented: $displayBlockUserAlert) {
                    Alert(title: Text("Block.Profile.Alert.Title", bundle: .module),
                          message: Text("Block.Profile.Alert.Message", bundle: .module),
                          primaryButton: .default(Text("Common.Cancel", bundle: .module)),
                          secondaryButton: .destructive(
                            Text("Common.Continue", bundle: .module),
                            action: viewModel.blockUser
                          )
                    )
                }
            }
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Block.Profile.Done.Title", bundle: .module),
                    isPresented: $viewModel.blockUserDone, actions: {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $viewModel.blockUserDone) {
                    Alert(title: Text("Block.Profile.Done.Title", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        presentationMode.wrappedValue.dismiss()
                    }))
                }
            }
        }
        .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction)
    }

    @ViewBuilder
    private var leadingBarItem: some View {
        EmptyView()
    }

    @ViewBuilder
    private var trailingBarItem: some View {
        if #available(iOS 14.0, *) {
            Menu(content: {
                Button(action: {
                    guard viewModel.ensureConnected(action: .moderation) else { return }
                    navigator.push(.reportProfile(profileId: viewModel.profileId))
                }) {
                    Label(title: { Text("Moderation.Profile.Button", bundle: .module) },
                          icon: { Image(systemName: "flag") })
                }
                Button(action: {
                    guard viewModel.ensureConnected(action: .blockUser) else { return }
                    displayBlockUserAlert = true
                }) {
                    Label(title: { Text("Block.Profile.Button", bundle: .module) },
                          icon: { Image(systemName: "person.slash") })
                }
            }, label: {
                if #available(iOS 26.0, *) {
                    Label(title: { Text("Settings.Community.Title", bundle: .module) },
                          icon: { Image(systemName: "ellipsis") })
                } else {
                    Image(systemName: "ellipsis")
                        .font(theme.fonts.navBarItem)
                        .padding(.vertical)
                        .padding(.leading)
                        .frame(minWidth: 44, minHeight: 44)
                }
            })
            .buttonStyle(.plain)
        } else {
            Button(action: { openActions = true }) {
                Image(systemName: "ellipsis")
                    .padding(.vertical)
                    .padding(.leading)
                    .font(theme.fonts.navBarItem)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ContentView<PostsView: View>: View {
    let profile: DisplayableProfile?
    let displayAccountAge: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let refresh: @Sendable () async -> Void

    @ViewBuilder let postsView: PostsView

    var body: some View {
        if let profile {
            VStack(spacing: 0) {
#if compiler(>=6.2)
                // Disable nav bar opacity on iOS 26 to have the same behavior as before.
                // TODO: See with product team if we need to keep it.
                if #available(iOS 26.0, *) {
                    Color.white.opacity(0.0001)
                        .frame(maxWidth: .infinity)
                        .frame(height: 1)
                }
#endif
                ProfileContentView(
                    profile: profile,
                    displayAccountAge: displayAccountAge,
                    zoomableImageInfo: $zoomableImageInfo, refresh: refresh) {
                        postsView
                }.padding(.top, 8)
                PoweredByOctopusView()
            }
        } else {
            Compat.ProgressView()
        }
    }
}

private struct ProfileContentView<PostsView: View>: View {
    @Environment(\.octopusTheme) private var theme
    let profile: DisplayableProfile
    let displayAccountAge: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let refresh: @Sendable () async -> Void
    @ViewBuilder let postsView: PostsView

    @State private var selectedTab = 0

    @State private var displayFullBio = false

    var body: some View {
        Compat.ScrollView(refreshAction: refresh) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 16) {
                        ZoomableAuthorAvatarView(avatar: avatar, zoomableImageInfo: $zoomableImageInfo)
                            .frame(width: 71, height: 71)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(profile.nickname ?? "")
                                .font(theme.fonts.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.colors.gray900)
                                .modify {
                                    if #available(iOS 15.0, *) {
                                        $0.textSelection(.enabled)
                                    } else { $0 }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if profile.tags.contains(.admin) {
                                Text("Profile.Tag.Admin", bundle: .module)
                                    .octopusBadgeStyle(.xs, status: .admin)
                            } else {
                                GamificationLevelBadge(level: profile.gamificationLevel, size: .big)
                            }
                        }
                    }

                    Spacer().frame(height: 16)

                    ProfileCounterView(totalMessages: profile.totalMessages,
                                       accountCreationDate: displayAccountAge ? profile.accountCreationDate : nil)

                    if let bio = profile.bio {
                        Group {
                            if bio.isEllipsized {
                                Text(verbatim: "\(bio.getText(ellipsized: !displayFullBio))\(!displayFullBio ? "... " : " ")")
                                +
                                Text(displayFullBio ? "Common.ReadLess" : "Common.ReadMore", bundle: .module)
                                    .fontWeight(.medium)
                                    .foregroundColor(theme.colors.gray500)
                            } else {
                                Text(bio.fullText)
                            }
                        }
                        .font(theme.fonts.body2)
                        .foregroundColor(theme.colors.gray900)
                        .modify {
                            if #available(iOS 15.0, *) {
                                $0.textSelection(.enabled)
                            } else { $0 }
                        }
                        .padding(.vertical, 5)
                        .onTapGesture {
                            withAnimation {
                                displayFullBio.toggle()
                            }
                        }
                    }
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)

                CustomSegmentedControl(tabs: ["Profile.Tabs.Posts"], tabCount: 3, selectedTab: $selectedTab)
                theme.colors.gray300.frame(height: 1)
                postsView
            }
        }
        .postsVisibilityScrollView()
    }

    private var avatar: Author.Avatar {
        if let pictureUrl = profile.pictureUrl {
            return .image(url: pictureUrl, name: profile.nickname ?? "")
        } else {
            return .defaultImage(name: profile.nickname ?? "")
        }
    }
}
