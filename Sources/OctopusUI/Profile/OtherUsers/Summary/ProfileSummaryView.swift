//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct ProfileSummaryView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: ProfileSummaryViewModel

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var displayPostDetailId: String?
    @State private var displayMostRecentComment = false
    @State private var displayPostDetail = false

    @State private var moderationContext: ReportView.Context?
    @State private var displayContentModeration = false

    @State private var displayBlockUserAlert = false

    @State private var openActions = false

    // TODO: Delete when router is fully used
    @State private var displaySSOError = false
    @State private var displayableSSOError: DisplayableString?

    init(octopus: OctopusSDK, profileId: String) {
        _viewModel = Compat.StateObject(wrappedValue: ProfileSummaryViewModel(octopus: octopus, profileId: profileId))
    }

    var body: some View {
        VStack {
            ContentView(profile: viewModel.profile, refresh: viewModel.refresh) {
                if let postFeedViewModel = viewModel.postFeedViewModel {
                    PostFeedView(
                        viewModel: postFeedViewModel,
                        displayPostDetail: {
                            displayPostDetailId = $0
                            displayMostRecentComment = $1
                            displayPostDetail = true
                        },
                        displayProfile: { _ in },
                        displayContentModeration: {
                            moderationContext = .content(contentId: $0)
                            displayContentModeration = true
                        }) {
                            DefaultEmptyPostsView()
                        }
                } else {
                    EmptyView()
                }
            }
            NavigationLink(destination:
                Group {
                    if let displayPostDetailId {
                        PostDetailView(octopus: viewModel.octopus, postUuid: displayPostDetailId,
                                       scrollToMostRecentComment: displayMostRecentComment)
                    } else {
                        EmptyView()
                    }
            }, isActive: $displayPostDetail) {
                EmptyView()
            }.hidden()
            NavigationLink(
                destination:Group {
                    if let moderationContext {
                        ReportView(octopus: viewModel.octopus, context: moderationContext)
                    } else { EmptyView() }
                },
                isActive:  $displayContentModeration) {
                    EmptyView()
                }.hidden()
        }
        .alert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
        .fullScreenCover(isPresented: $viewModel.openLogin) {
            MagicLinkView(octopus: viewModel.octopus, isLoggedIn: .constant(false))
                .environment(\.dismissModal, $viewModel.openLogin)
        }
        .fullScreenCover(isPresented: $viewModel.openCreateProfile) {
            NavigationView {
                CreateProfileView(octopus: viewModel.octopus, isLoggedIn: .constant(false))
                    .environment(\.dismissModal, $viewModel.openCreateProfile)
            }
            .navigationBarHidden(true)
            .accentColor(theme.colors.primary)
        }
        .navigationBarItems(
            trailing:
                Group {
                    if #available(iOS 14.0, *) {
                        Menu(content: {
                            Button(action: {
                                guard viewModel.ensureConnected() else { return }
                                moderationContext = .profile(profileId: viewModel.profileId)
                                displayContentModeration = true
                            }) {
                                Label(L10n("Moderation.Profile.Button"), systemImage: "flag")
                            }
                            Button(action: {
                                guard viewModel.ensureConnected() else { return }
                                displayBlockUserAlert = true
                            }) {
                                Label(L10n("Block.Profile.Button"), systemImage: "person.slash")
                            }
                        }, label: {
                            VStack {
                                Image(systemName: "ellipsis")
                                    .padding(.vertical)
                                    .padding(.leading)
                                    .font(theme.fonts.navBarItem)
                            }.frame(width: 32, height: 32)
                        })
                    } else {
                        Button(action: { openActions = true }) {
                            Image(systemName: "ellipsis")
                                .padding(.vertical)
                                .padding(.leading)
                                .font(theme.fonts.navBarItem)
                        }
                    }
                }
        )
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
                    guard viewModel.ensureConnected() else { return }
                    moderationContext = .profile(profileId: viewModel.profileId)
                    displayContentModeration = true
                },
                ActionSheet.Button.destructive(Text("Block.Profile.Button", bundle: .module)) {
                    guard viewModel.ensureConnected() else { return }
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
        .alert(
            "Common.Error",
            isPresented: $displaySSOError,
            presenting: displayableSSOError,
            actions: { _ in
                Button(action: viewModel.linkClientUserToOctopusUser) {
                    Text("Common.Retry", bundle: .module)
                }
                Button(action: {}) {
                    Text("Common.Cancel", bundle: .module)
                }
            },
            message: { error in
                error.textView
            })
        .onReceive(viewModel.$ssoError) { error in
            guard let error else { return }
            displayableSSOError = error
            displaySSOError = true
        }
    }
}

private struct ContentView<PostsView: View>: View {
    let profile: Profile?
    let refresh: @Sendable () async -> Void

    @ViewBuilder let postsView: PostsView

    var body: some View {
        if let profile {
            ProfileContentView(profile: profile, refresh: refresh) {
                postsView
            }
        } else {
            Compat.ProgressView()
        }
    }
}

private struct ProfileContentView<PostsView: View>: View {
    @Environment(\.octopusTheme) private var theme
    let profile: Profile
    let refresh: @Sendable () async -> Void
    @ViewBuilder let postsView: PostsView

    @State private var selectedTab = 0

    var body: some View {
        Compat.ScrollView(refreshAction: refresh) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 20)
                    AuthorAvatarView(avatar: avatar)
                        .frame(width: 71, height: 71)
                    Spacer().frame(height: 14)
                    Text(profile.nickname ?? "")
                        .font(theme.fonts.title1)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.gray900)
                        .modify {
                            if #available(iOS 15.0, *) {
                                $0.textSelection(.enabled)
                            } else { $0 }
                        }

                    Spacer().frame(height: 10)
                    if let bio = profile.bio?.nilIfEmpty {
                        Text(bio)
                            .font(theme.fonts.body2)
                            .foregroundColor(theme.colors.gray500)
                            .modify {
                                if #available(iOS 15.0, *) {
                                    $0.textSelection(.enabled)
                                } else { $0 }
                            }
                    }
                    Spacer().frame(height: 20)
                    CustomSegmentedControl(tabs: ["Profile.Tabs.Posts"], tabCount: 3, selectedTab: $selectedTab)
                }
                .padding(.horizontal, 20)
                theme.colors.gray300.frame(height: 1)
                postsView
            }
        }
    }

    private var avatar: Author.Avatar {
        if let pictureUrl = profile.pictureUrl {
            return .image(url: pictureUrl, name: profile.nickname ?? "")
        } else {
            return .defaultImage(name: profile.nickname ?? "")
        }
    }
}
