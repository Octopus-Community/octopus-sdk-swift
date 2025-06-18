//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct ProfileSummaryView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: ProfileSummaryViewModel

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var displayBlockUserAlert = false

    @State private var openActions = false

    @State private var noConnectedReplacementAction: ConnectedActionReplacement?

    @State private var zoomableImageInfo: ZoomableImageInfo?

    init(octopus: OctopusSDK, profileId: String) {
        _viewModel = Compat.StateObject(wrappedValue: ProfileSummaryViewModel(octopus: octopus, profileId: profileId))
    }

    var body: some View {
        VStack {
            ContentView(profile: viewModel.profile, zoomableImageInfo: $zoomableImageInfo, refresh: viewModel.refresh) {
                if let postFeedViewModel = viewModel.postFeedViewModel {
                    PostFeedView(
                        viewModel: postFeedViewModel,
                        zoomableImageInfo: $zoomableImageInfo,
                        displayPostDetail: {
                            navigator.push(.postDetail(postId: $0, comment: $1, commentToScrollTo: nil,
                                                       scrollToMostRecentComment: $2))
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
        .alert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
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
                    navigator.push(.reportProfile(profileId: viewModel.profileId))
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
                    guard viewModel.ensureConnected() else { return }
                    navigator.push(.reportProfile(profileId: viewModel.profileId))
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
            .buttonStyle(.plain)
        } else {
            Button(action: { openActions = true }) {
                Image(systemName: "ellipsis")
                    .padding(.vertical)
                    .padding(.leading)
                    .font(theme.fonts.navBarItem)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ContentView<PostsView: View>: View {
    let profile: Profile?
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let refresh: @Sendable () async -> Void

    @ViewBuilder let postsView: PostsView

    var body: some View {
        if let profile {
            VStack(spacing: 0) {
                ProfileContentView(profile: profile, zoomableImageInfo: $zoomableImageInfo, refresh: refresh) {
                    postsView
                }
                PoweredByOctopusView()
            }
        } else {
            Compat.ProgressView()
        }
    }
}

private struct ProfileContentView<PostsView: View>: View {
    @Environment(\.octopusTheme) private var theme
    let profile: Profile
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let refresh: @Sendable () async -> Void
    @ViewBuilder let postsView: PostsView

    @State private var selectedTab = 0

    var body: some View {
        Compat.ScrollView(refreshAction: refresh) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 20)
                    ZoomableAuthorAvatarView(avatar: avatar, zoomableImageInfo: $zoomableImageInfo)
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
