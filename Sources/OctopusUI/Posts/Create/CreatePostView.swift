//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct CreatePostView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: CreatePostViewModel

    @State private var showTopicPicker = false
    @State private var displayError = false
    @State private var displayableError: DisplayableString?
    @State private var topicPickerDetentHeight: CGFloat = 0
    @State private var showChangesWillBeLostAlert = false

    init(octopus: OctopusSDK) {
        _viewModel = Compat.StateObject(wrappedValue: CreatePostViewModel(octopus: octopus))
    }

    var body: some View {
        NavigationView {
            ContentView(isLoading: viewModel.isLoading,
                        headline: $viewModel.headline,
                        text: $viewModel.text,
                        picture: $viewModel.picture,
                        headlineError: viewModel.headlineError,
                        textError: viewModel.textError,
                        pictureError: viewModel.pictureError,
                        userAvatar: viewModel.userAvatar ?? .defaultImage(name: "?"),
                        selectedTopic: viewModel.selectedTopic,
                        showTopicPicker: $showTopicPicker)
            .navigationBarTitle(Text("Post.Create.Title", bundle: .module), displayMode: .inline)
            .navigationBarItems(leading: cancelButton, trailing: postButton)
            .sheet(isPresented: $showTopicPicker) {
                if #available(iOS 16.0, *) {
                    TopicPicker(topics: viewModel.topics, selectedTopic: $viewModel.selectedTopic)
                    .readHeight()
                    .onPreferenceChange(HeightPreferenceKey.self) { [$topicPickerDetentHeight] height in
                        if let height {
                            // add a small padding otherwise multi line texts are not correctly rendered
                            // TODO: change that fixed size to a ScaledMetric (but not available on iOS 13)
                            $topicPickerDetentHeight.wrappedValue = height + 40
                        }
                    }
                    .presentationDetents([.height(topicPickerDetentHeight)])
                    .presentationDragIndicator(.visible)
                    .modify {
                        if #available(iOS 16.4, *) {
                            $0.presentationContentInteraction(.scrolls)
                        } else {
                            $0
                        }
                    }

                } else {
                    Picker("Post.Create.Topic.Selection.Button", selection: $viewModel.selectedTopic) {
                        ForEach(viewModel.topics, id: \.self) {
                            Text($0.name)
                                .tag($0)
                        }
                    }.pickerStyle(.wheel)
                }
            }
            .alert(
                "Common.Error",
                isPresented: $displayError,
                presenting: displayableError,
                actions: { _ in

                }, message: { error in
                    error.textView
                })
            .modify {
                if #available(iOS 15.0, *) {
                    $0.alert(
                        Text("Common.CancelModifications", bundle: .module),
                        isPresented: $showChangesWillBeLostAlert) {
                            Button(L10n("Common.No"), role: .cancel, action: {})
                            Button(L10n("Common.Yes"), role: .destructive, action: { presentationMode.wrappedValue.dismiss() })
                        }
                } else {
                    $0.alert(isPresented: $showChangesWillBeLostAlert) {
                        Alert(title: Text("Common.CancelModifications", bundle: .module),
                              primaryButton: .default(Text("Common.No", bundle: .module)),
                              secondaryButton: .destructive(
                                Text("Common.Yes", bundle: .module),
                                action: { presentationMode.wrappedValue.dismiss() }
                              )
                        )
                    }
                }
            }
            .onReceive(viewModel.$dismiss) { shouldDismiss in
                guard shouldDismiss else { return }
                presentationMode.wrappedValue.dismiss()
            }
            .onReceive(viewModel.$alertError) { displayableError in
                guard let displayableError else { return }
                self.displayableError = displayableError
                displayError = true
            }
            .onValueChanged(of: displayError) {
                guard !$0 else { return }
                viewModel.alertError = nil
            }
        }
        .accentColor(theme.colors.accent)
    }

    @ViewBuilder
    private var cancelButton: some View {
        Button(action: {
            if viewModel.hasChanges {
                showChangesWillBeLostAlert = true
            } else {
                presentationMode.wrappedValue.dismiss()
            }
        }) {
            Text("Common.Cancel", bundle: .module)
                .font(theme.fonts.navBarItem)
        }
    }

    @ViewBuilder
    private var postButton: some View {
        if !viewModel.isLoading {
            Button(action: {
                if viewModel.selectedTopic == nil {
                    showTopicPicker = true
                } else {
                    viewModel.send()
                }
            }) {
                Text("Post.Create.Button", bundle: .module)
                    .font(theme.fonts.navBarItem)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.sendButtonAvailable ? theme.colors.accent : theme.colors.disabled)
            }
            .disabled(!viewModel.sendButtonAvailable)
        } else {
            if #available(iOS 14.0, *) {
                ProgressView()
            } else {
                Button(action: { }) {
                    Text("Post.Create.Button", bundle: .module)
                        .font(theme.fonts.navBarItem)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.disabled)
                }
                .disabled(true)
            }
        }
    }
}

private struct ContentView: View {
    let isLoading: Bool
    @Binding var headline: String
    @Binding var text: String
    @Binding var picture: ImageAndData?

    let headlineError: DisplayableString?
    let textError: DisplayableString?
    let pictureError: DisplayableString?

    let userAvatar: Author.Avatar
    let selectedTopic: CreatePostViewModel.DisplayableTopic?

    @Binding var showTopicPicker: Bool

    var body: some View {
        ZStack {
            WritingPostForm(headline: $headline, text: $text, picture: $picture,
                            headlineError: headlineError, textError: textError, pictureError: pictureError,
                            userAvatar: userAvatar, selectedTopic: selectedTopic,
                            showTopicPicker: $showTopicPicker)
            .disabled(isLoading)
        }
    }
}

private struct WritingPostForm: View {
    @Environment(\.octopusTheme) private var theme
    @Binding var headline: String
    @Binding var text: String
    @Binding var picture: ImageAndData?

    let headlineError: DisplayableString?
    let textError: DisplayableString?
    let pictureError: DisplayableString?

    let userAvatar: Author.Avatar
    let selectedTopic: CreatePostViewModel.DisplayableTopic?
    @Binding var showTopicPicker: Bool

    @State private var selectedItems: [ImageAndData] = []
    @State private var imagePickingError: Error?
    @State private var headlineFocused = true
    @State private var textFocused = false
    @State private var openPhotosPicker = false
    @State private var scrollToBottomOfId: String?

    var body: some View {
        VStack {
            theme.colors.gray200
                .frame(maxWidth: .infinity)
                .frame(height: 1)
            Compat.ScrollView(scrollToId: $scrollToBottomOfId, idAnchor: .bottom) {
                VStack {
                    VStack(alignment: .leading) {
                        HStack(spacing: 10) {
                            AuthorAvatarView(avatar: userAvatar)
                                .frame(width: 33, height: 33)
                            Button(action: {
                                showTopicPicker = true
                                headlineFocused = false
                                textFocused = false
                            }) {
                                TopicSelectionCapsule(topic: selectedTopic?.name)
                            }
                        }
                        Spacer()
                            .frame(height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            if #available(iOS 16.0, *) {
                                TextField(String(""), text: $headline, axis: .vertical)
                                    .multilineTextAlignment(.leading)
                                    .focused($headlineFocused)
                                    .foregroundColor(theme.colors.gray600)
                                    .placeholder(when: headline.isEmpty) {
                                        Text("Post.Create.Headline.Placeholder", bundle: .module)
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(theme.colors.gray400)
                                    }
                                    .font(theme.fonts.body2)
                                    .fontWeight(.semibold)
                                    .onValueChanged(of: headline) {
                                        if $0.contains("\n") {
                                            headlineFocused = false
                                            headline = $0.replacingOccurrences(of: "\n", with: "")
                                        }
                                    }
                            } else {
                                TextField(String(""), text: $headline)
                                    .multilineTextAlignment(.leading)
                                    .focused($headlineFocused)
                                    .foregroundColor(theme.colors.gray600)
                                    .placeholder(when: headline.isEmpty) {
                                        Text("Post.Create.Headline.Placeholder", bundle: .module)
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(theme.colors.gray400)
                                    }
                                    .font(theme.fonts.body2.weight(.semibold))
                            }
                            if let headlineError {
                                theme.colors.error.frame(height: 1)
                                Spacer().frame(height: 4)
                                headlineError.textView
                                    .font(theme.fonts.caption2)
                                    .bold()
                                    .foregroundColor(theme.colors.error)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Spacer().frame(height: 20)
                            if #available(iOS 16.0, *) {
                                TextField(String(""), text: $text, axis: .vertical)
                                    .multilineTextAlignment(.leading)
                                    .focused($textFocused)
                                    .foregroundColor(theme.colors.gray600)
                                    .placeholder(when: text.isEmpty) {
                                        Text("Post.Create.Text.Placeholder", bundle: .module)
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(theme.colors.gray400)
                                    }
                                    .font(theme.fonts.body2)
                                    .id("textInputView")
                                    .onChange(of: text) { [oldValue = text] newValue in
                                        // only scroll to bottom if the last line changed
                                        let previousLastLine = oldValue.components(separatedBy: "\n").last ?? ""
                                        let newLastLine = newValue.components(separatedBy: "\n").last ?? ""
                                        if previousLastLine != newLastLine {
                                            scrollToBottomOfId = "textInputView"
                                        }
                                    }

                            } else {
                                // TODO: create a TextField that expands vertically on iOS 13
                                TextField(String(""), text: $text)
                                    .multilineTextAlignment(.leading)
                                    .focused($textFocused)
                                    .foregroundColor(theme.colors.gray600)
                                    .placeholder(when: text.isEmpty) {
                                        Text("Post.Create.Text.Placeholder", bundle: .module)
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(theme.colors.gray400)
                                    }
                                    .font(theme.fonts.body2)
                            }
                            if let imageAndData = picture {
                                Spacer().frame(height: 10)
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: imageAndData.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                    Button(action: {
                                        picture = nil
                                        selectedItems = []
                                    }) {
                                        Image(systemName: "xmark")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .font(theme.fonts.body1.bold())
                                            .padding(10)
                                            .foregroundColor(theme.colors.gray500)
                                            .background(
                                                Circle()
                                                    .foregroundColor(theme.colors.gray200)

                                            )
                                            .frame(width: 32, height: 32)
                                            .padding()

                                    }
                                }
                            } else if text.isEmpty {
                                // when there is no picture displayed, use the remaining part of the screen to catch tap
                                Color(UIColor.systemBackground)
                                    .frame(height: 150)
                                    .onTapGesture {
                                        textFocused = true
                                    }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }
            }
            VStack(spacing: 0) {
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
                            .padding(.horizontal, 16)
                        Spacer().frame(height: 4)
                    }

                    if let pictureError {
                        pictureError.textView
                            .font(theme.fonts.caption2)
                            .bold()
                            .foregroundColor(theme.colors.error)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        Spacer().frame(height: 4)
                    }
                }

                theme.colors.gray200.frame(height: 1)

                HStack {
                    Button(action: { openPhotosPicker = true }) {
                        Image(.addMedia)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .padding()
                    }
                    Spacer()
                }
            }
        }
        .imagesPicker(isPresented: $openPhotosPicker, selection: $selectedItems, error: $imagePickingError,
                      maxSelectionCount: 1)
        .onValueChanged(of: selectedItems) {
            picture = $0.first
        }
        .onValueChanged(of: picture) {
            if $0 == nil {
                selectedItems = []
            }
        }
    }
}

#Preview {
    ContentView(isLoading: false, headline: .constant(""), text: .constant(""), picture: .constant(nil),
                headlineError: nil, textError: nil, pictureError: nil,
                userAvatar: .defaultImage(name: "toto"),
                selectedTopic: nil, showTopicPicker: .constant(false))
}
