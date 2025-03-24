//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct CurrentUserProfileSummaryView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: CurrentUserProfileSummaryViewModel

    @Binding private var dismiss: Bool

    @State private var openEditionScreen = false
    @State private var openSettings = false
    @State private var openCreatePost = false
    @State private var displayDeleteUserAlert = false

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var bioFocused = false
    @State private var photoPickerFocused = false

    @State private var displayPostDetailId: String?
    @State private var displayMostRecentComment = false
    @State private var displayPostDetail = false

    @State private var displayModerateId: String?
    @State private var displayContentModeration = false

    init(octopus: OctopusSDK, dismiss: Binding<Bool>) {
        _viewModel = Compat.StateObject(wrappedValue: CurrentUserProfileSummaryViewModel(octopus: octopus))
        _dismiss = dismiss
    }

    var body: some View {
        VStack {
            ContentView(profile: viewModel.profile, refresh: viewModel.refresh, openEdition: {
                if let editProfileCallback = viewModel.editProfileCallback {
                    editProfileCallback(nil)
                } else {
                    photoPickerFocused = false
                    bioFocused = false
                    openEditionScreen = true
                }
            }, openEditionWithBioFocused: {
                if let editProfileCallback = viewModel.editProfileCallback {
                    editProfileCallback(.bio)
                } else {
                    photoPickerFocused = false
                    bioFocused = true
                    openEditionScreen = true
                }
            }, openEditionWithPhotoPicker: {
                if let editProfileCallback = viewModel.editProfileCallback {
                    editProfileCallback(.picture)
                } else {
                    photoPickerFocused = true
                    bioFocused = false
                    openEditionScreen = true
                }
            }) {
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
                            displayModerateId = $0
                            displayContentModeration = true
                        }) {
                            CreatePostEmptyPostView(createPost: { openCreatePost = true })
                        }
                } else {
                    EmptyView()
                }
            }
            NavigationLink(destination: EditProfileView(octopus: viewModel.octopus, bioFocused: bioFocused,
                                                        photoPickerFocused: photoPickerFocused),
                           isActive: $openEditionScreen) {
                EmptyView()
            }.hidden()
            NavigationLink(destination: SettingsListView(octopus: viewModel.octopus, popToRoot: $dismiss,
                                                         preventAutoDismiss: $viewModel.preventAutoDismiss),
                           isActive: $openSettings) {
                EmptyView()
            }.hidden()
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
                    if let displayModerateId {
                        ReportView(octopus: viewModel.octopus,
                                   context: .content(contentId: displayModerateId))
                    } else { EmptyView() }
                },
                isActive:  $displayContentModeration) {
                    EmptyView()
                }.hidden()
        }
        .fullScreenCover(isPresented: $openCreatePost) {
            CreatePostView(octopus: viewModel.octopus)
        }
        .alert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
        .navigationBarItems(
            trailing:
                Button(action: { openSettings = true }) {
                    Image(systemName: "ellipsis")
                        .padding(.vertical)
                        .padding(.leading)
                        .font(theme.fonts.navBarItem)
                }
        )
        .onReceive(viewModel.$error) { error in
            guard let error else { return }
            displayableError = error
            displayError = true
        }
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            dismiss = true
        }
        .onValueChanged(of: displayError) {
            guard !$0 else { return }
            viewModel.error = nil
        }
    }
}

private struct ContentView<PostsView: View>: View {
    let profile: CurrentUserProfile?
    let refresh: @Sendable () async -> Void
    let openEdition: () -> Void
    let openEditionWithBioFocused: () -> Void
    let openEditionWithPhotoPicker: () -> Void

    @ViewBuilder let postsView: PostsView

    var body: some View {
        if let profile {
            ProfileContentView(profile: profile, refresh: refresh, openEdition: openEdition,
                               openEditionWithBioFocused: openEditionWithBioFocused,
                               openEditionWithPhotoPicker: openEditionWithPhotoPicker) {
                postsView
            }
        } else {
            Compat.ProgressView()
                .frame(width: 60)
        }
    }
}

private struct ProfileContentView<PostsView: View>: View {
    @Environment(\.octopusTheme) private var theme
    let profile: CurrentUserProfile
    let refresh: @Sendable () async -> Void
    let openEdition: () -> Void
    let openEditionWithBioFocused: () -> Void
    let openEditionWithPhotoPicker: () -> Void
    @ViewBuilder let postsView: PostsView

    @State private var selectedTab = 0

    var body: some View {
        Compat.ScrollView(refreshAction: refresh) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        if case .defaultImage = avatar {
                            Button(action: openEditionWithPhotoPicker) {
                                AuthorAvatarView(avatar: avatar)
                                    .frame(width: 71, height: 71)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .foregroundColor(theme.colors.onPrimary)
                                            .padding(4)
                                            .background(theme.colors.primary)
                                            .clipShape(Circle())
                                            .frame(width: 20, height: 20)
                                            .offset(x: 26, y: 26)
                                    )
                            }
                            .buttonStyle(.plain)
                        } else {
                            AuthorAvatarView(avatar: avatar)
                                .frame(width: 71, height: 71)
                        }
                        Spacer()
                        Button(action: openEdition) {
                            Text("Profile.Edit.Button", bundle: .module)
                                .font(theme.fonts.body2)
                                .fontWeight(.medium)
                                .foregroundColor(theme.colors.gray900)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        .background(
                            Capsule()
                                .stroke(theme.colors.gray300, lineWidth: 1)
                        )
                        .padding(1)
                    }
                    Spacer().frame(height: 20)
                    Text(profile.nickname)
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
                        Text(bio.cleanedBio)
                            .font(theme.fonts.body2)
                            .foregroundColor(theme.colors.gray900)
                            .modify {
                                if #available(iOS 15.0, *) {
                                    $0.textSelection(.enabled)
                                } else { $0 }
                            }
                    } else {
                        Button(action: openEditionWithBioFocused) {
                            HStack {
                                Text("Profile.Detail.EmptyBio.Button", bundle: .module)
                                    .font(theme.fonts.body2)
                                Image(.createPost)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2]))

                            )
                            .foregroundColor(theme.colors.gray900)
                        }
                        .buttonStyle(.plain)
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
            return .image(url: pictureUrl, name: profile.nickname)
        } else {
            return .defaultImage(name: profile.nickname)
        }
    }
}
