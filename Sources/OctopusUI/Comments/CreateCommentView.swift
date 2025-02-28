//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct CreateCommentView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: CreateCommentViewModel

    @Binding var textFocused: Bool
    @Binding var hasChanges: Bool

    @State private var displayError = false
    @State private var displayableError: DisplayableString?
    @State private var openUserProfile = false
    @State private var dismissCurrentProfileFlow = false

    init(octopus: OctopusSDK, postId: String, textFocused: Binding<Bool>, hasChanges: Binding<Bool>) {
        _viewModel = Compat.StateObject(wrappedValue: CreateCommentViewModel(octopus: octopus, postId: postId))
        self._textFocused = textFocused
        self._hasChanges = hasChanges
    }

    var body: some View {
        ContentView(avatar: viewModel.avatar, isLoading: viewModel.isLoading, sendAvailable: viewModel.sendAvailable,
                    text: $viewModel.text, picture: $viewModel.picture, textFocused: $textFocused,
                    textError: viewModel.textError, pictureError: viewModel.pictureError, send: viewModel.send,
                    userProfileTapped: { openUserProfile = true })
        .disabled(viewModel.isLoading)
        .alert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
        .onReceive(viewModel.$alertError) { displayableError in
            guard let displayableError else { return }
            self.displayableError = displayableError
            displayError = true
        }
        .onReceive(viewModel.$hasChanges) {
            hasChanges = $0
        }
        .onValueChanged(of: dismissCurrentProfileFlow) {
            guard $0 else { return }
            openUserProfile = false
        }
        .background(
            NavigationLink(destination: CurrentUserProfileSummaryView(octopus: viewModel.octopus,
                                                                      dismiss: !$openUserProfile),
                           isActive: $openUserProfile) {
                               EmptyView()
                           }.hidden()
        )
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let avatar: Author.Avatar
    let isLoading: Bool
    let sendAvailable: Bool
    @Binding var text: String
    @Binding var picture: ImageAndData?
    @Binding var textFocused: Bool

    let textError: DisplayableString?
    let pictureError: DisplayableString?

    let send: () -> Void
    let userProfileTapped: () -> Void

    @State private var selectedItems: [ImageAndData] = []
    @State private var imagePickingError: Error?
    @State private var openPhotosPicker = false

    var body: some View {
        VStack(spacing: 0) {
            theme.colors.gray200.frame(height: 1)
            Spacer().frame(height: 8)
            HStack(alignment: .top) {
                Button(action: userProfileTapped) {
                    AuthorAvatarView(avatar: avatar)
                }
                .frame(width: 33, height: 33)
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        if #available(iOS 16.0, *) {
                            TextField(String(""), text: $text, axis: .vertical)
                                .multilineTextAlignment(.leading)
                                .lineLimit(picture != nil ? 4 : 5)
                                .focused($textFocused)
                                .foregroundColor(theme.colors.gray600)
                                .placeholder(when: text.isEmpty) {
                                    Text("Comment.Create.Text.Placeholder", bundle: .module)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(theme.colors.gray400)
                                }
                                .font(theme.fonts.body2)
                        } else {
                            // TODO: create a TextField that expands vertically on iOS 13
                            TextField(String(""), text: $text)
                                .multilineTextAlignment(.leading)
                                .lineLimit(picture != nil ? 4 : 5)
                                .focused($textFocused)
                                .foregroundColor(theme.colors.gray600)
                                .placeholder(when: text.isEmpty) {
                                    Text("Comment.Create.Text.Placeholder", bundle: .module)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(theme.colors.gray400)
                                }
                                .font(theme.fonts.body2)
                        }
                        if let imageAndData = picture {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: imageAndData.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 150)
                                    .cornerRadius(12)
                                Button(action: {
                                    picture = nil
                                    selectedItems = []
                                }) {
                                    Image(systemName: "xmark")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .font(theme.fonts.body1.bold())
                                        .padding(8)
                                        .foregroundColor(theme.colors.gray500)
                                        .background(
                                            Circle()
                                                .foregroundColor(theme.colors.gray200)

                                        )
                                        .frame(width: 26, height: 26)
                                        .padding(4)

                                }
                            }
                        }
                    }
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.colors.gray200, lineWidth: 1)
                            .onTapGesture {
                                textFocused = true
                            }
                    )
                    if pictureError != nil || textError != nil {
                        theme.colors.error.frame(height: 1)
                        Spacer().frame(height: 4)

                        if let textError {
                            textError.textView
                                .font(theme.fonts.caption2)
                                .bold()
                                .foregroundColor(theme.colors.error)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer().frame(height: 4)
                        }

                        if let pictureError {
                            pictureError.textView
                                .font(theme.fonts.caption2)
                                .bold()
                                .foregroundColor(theme.colors.error)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer().frame(height: 4)
                        }
                    }
                }
            }.padding(.horizontal, 16)

            HStack {
                Button(action: { openPhotosPicker = true }) {
                    Image(.addMedia)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .padding(.vertical, 8)
                }
                Spacer()
                Button(action: {
                    textFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    send()
                }) {
                    HStack(spacing: 8) {
                        if isLoading {
                            Compat.ProgressView(tint: theme.colors.textOnAccent)
                        }
                        Text("Comment.Create.Button", bundle: .module)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.textOnAccent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().foregroundColor(
                            sendAvailable && !isLoading ? theme.colors.accent : theme.colors.disabled)
                    )
                }.disabled(!sendAvailable || isLoading)
                    .modify {
                        if #available(iOS 17.0, *) {
                            $0.geometryGroup()
                        } else {
                            $0
                        }
                    }
            }
            .padding(.horizontal, 16)
        }
        .layoutPriority(1)
        .gesture(DragGesture(minimumDistance: 10, coordinateSpace: .global).onEnded { value in
            let horizontalAmount = value.translation.width
            let verticalAmount = value.translation.height

            if abs(horizontalAmount) < abs(verticalAmount) {
                textFocused = false
            }
        })
        .imagesPicker(isPresented: $openPhotosPicker, selection: $selectedItems, error: $imagePickingError,
                      maxSelectionCount: 1)
        .onValueChanged(of: selectedItems) {
            guard let imagePickerItem = $0.first else { return }
            picture = imagePickerItem
        }
        .onValueChanged(of: picture) {
            if $0 == nil {
                selectedItems = []
            }
        }
    }
}
