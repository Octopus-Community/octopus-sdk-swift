//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct CreatePostView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: CreatePostViewModel

    @State private var showTopicPicker = false
    @State private var displayError = false
    @State private var displayableError: DisplayableString?
    @State private var topicPickerDetentHeight: CGFloat = 80
    @State private var showChangesWillBeLostAlert = false
    @State private var height: CGFloat = 0

    init(octopus: OctopusSDK, withPoll: Bool) {
        _viewModel = Compat.StateObject(wrappedValue: CreatePostViewModel(octopus: octopus, withPoll: withPoll))
    }

    var body: some View {
        ContentView(isLoading: viewModel.isLoading,
                    text: $viewModel.text,
                    attachment: $viewModel.attachment,
                    textError: viewModel.textError,
                    pictureError: viewModel.pictureError,
                    pollError: viewModel.pollError,
                    userAvatar: viewModel.userAvatar ?? .defaultImage(name: "?"),
                    selectedTopic: viewModel.selectedTopic,
                    showTopicPicker: $showTopicPicker,
                    createPoll: viewModel.createPoll)
        .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction)
        .navigationBarTitle(Text("Post.Create.Title", bundle: .module), displayMode: .inline)
        .navigationBarBackButtonHidden(viewModel.hasChanges)
        .toolbar(leading: cancelButton, trailing: postButton,
                             trailingSharedBackgroundVisibility: .hidden)
        .sheet(isPresented: $showTopicPicker) {
            if #available(iOS 16.0, *) {
                TopicPicker(topics: viewModel.topics, selectedTopic: $viewModel.selectedTopic)
                    .readHeight($height)
                    .onValueChanged(of: height) { [$topicPickerDetentHeight] height in
                        $topicPickerDetentHeight.wrappedValue = height
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
        .compatAlert(
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

    @ViewBuilder
    private var cancelButton: some View {
        if viewModel.hasChanges {
            BackButton(action: { showChangesWillBeLostAlert = true })
        } else {
            EmptyView()
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
            }
            .buttonStyle(OctopusButtonStyle(.mid, enabled: viewModel.sendButtonAvailable))
            .disabled(!viewModel.sendButtonAvailable)
        } else {
            if #available(iOS 14.0, *) {
                ProgressView()
            } else {
                Button(action: { }) {
                    Text("Post.Create.Button", bundle: .module)
                }
                .buttonStyle(OctopusButtonStyle(.mid, enabled: true))
                .disabled(true)
            }
        }
    }
}

private struct ContentView: View {
    let isLoading: Bool
    @Binding var text: String
    @Binding var attachment: CreatePostViewModel.Attachment?

    let textError: DisplayableString?
    let pictureError: DisplayableString?
    let pollError: DisplayableString?

    let userAvatar: Author.Avatar
    let selectedTopic: CreatePostViewModel.DisplayableTopic?

    @Binding var showTopicPicker: Bool
    let createPoll: () -> Void

    var body: some View {
        WritingPostForm(text: $text, attachment: $attachment,
                        textError: textError, pictureError: pictureError, pollError: pollError,
                        userAvatar: userAvatar, selectedTopic: selectedTopic,
                        showTopicPicker: $showTopicPicker,
                        createPoll: createPoll)
        .disabled(isLoading)
    }
}

private struct WritingPostForm: View {
    @Environment(\.octopusTheme) private var theme
    @Binding var text: String
    @Binding var attachment: CreatePostViewModel.Attachment?

    let textError: DisplayableString?
    let pictureError: DisplayableString?
    let pollError: DisplayableString?

    let userAvatar: Author.Avatar
    let selectedTopic: CreatePostViewModel.DisplayableTopic?
    @Binding var showTopicPicker: Bool
    let createPoll: () -> Void

    @State private var selectedItems: [ImageAndData] = []
    @State private var imagePickingError: Error?
    @State private var textFocused = true
    @State private var openPhotosPicker = false
    @State private var scrollToBottomOfId: String?

    var body: some View {
        VStack {
            Color.white.opacity(0.0001)
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
                                textFocused = false
                            }) {
                                HStack(spacing: 8) {
                                    if let topic = selectedTopic?.name {
                                        Text(topic)
                                    } else {
                                        Text("Post.Create.Topic.Selection.Button", bundle: .module)
                                    }
                                    Image(systemName: "chevron.down")
                                }
                            }
                            .buttonStyle(OctopusButtonStyle(.mid, style: .secondary, hasTrailingIcon: true))
                        }
                        Spacer()
                            .frame(height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            if #available(iOS 16.0, *) {
                                TextField(String(""), text: $text, axis: .vertical)
                                    .multilineTextAlignment(.leading)
                                    .focused($textFocused)
                                    .foregroundColor(theme.colors.gray900)
                                    .placeholder(when: text.isEmpty) {
                                        Text("Post.Create.Text.Placeholder", bundle: .module)
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(theme.colors.gray700)
                                    }
                                    .font(theme.fonts.body1)
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
                                    .foregroundColor(theme.colors.gray900)
                                    .placeholder(when: text.isEmpty) {
                                        Text("Post.Create.Text.Placeholder", bundle: .module)
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(theme.colors.gray700)
                                    }
                                    .font(theme.fonts.body1)
                            }
                            switch attachment {
                            case let .image(imageAndData):
                                Spacer().frame(height: 10)
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: imageAndData.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                    Button(action: {
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
                                    .buttonStyle(.plain)
                                }
                            case let .poll(editablePoll):
                                Spacer().frame(height: 10)
                                CreatePollView(
                                    poll: Binding(get: { editablePoll }, set: { attachment = .poll($0) }),
                                    deletePoll: {
                                        attachment = nil
                                    })
                            case nil:
                                if text.isEmpty {
                                    // when there is no attachment displayed, use the remaining part of the screen to
                                    // catch tap
                                    Color(UIColor.systemBackground)
                                        .frame(height: 150)
                                        .onTapGesture {
                                            textFocused = true
                                        }
                                } else {
                                    EmptyView()
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
                if pictureError != nil || textError != nil || pollError != nil {
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

                    if let pollError {
                        pollError.textView
                            .font(theme.fonts.caption2)
                            .bold()
                            .foregroundColor(theme.colors.error)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        Spacer().frame(height: 4)
                    }
                }

                if !(attachment?.hasPoll ?? false) {

                    HStack(spacing: 8) {
                        if !(attachment?.hasPoll ?? false) {
                            Button(action: { openPhotosPicker = true }) {
                                HStack(spacing: 4) {
                                    Image(res: .addMedia)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                    Text("Content.Create.AddPicture", bundle: .module)
                                }
                            }
                            .buttonStyle(OctopusButtonStyle(.mid, style: .outline, hasLeadingIcon: true))
                        }
                        if attachment == nil {
                            Button(action: {
                                withAnimation {
                                    createPoll()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(res: .poll)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                    Text("Content.Create.AddPoll", bundle: .module)
                                }
                            }
                            .buttonStyle(OctopusButtonStyle(.mid, style: .outline, hasLeadingIcon: true))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, textFocused ? 16 : 0)
                    .background(RoundedRectangle(cornerRadius: 24)
                        .stroke(theme.colors.gray300, lineWidth: 1)
                        .padding(.horizontal, -1)
                        .foregroundColor(Color(.systemBackground))
                        .overlay(
                            Rectangle()
                                .padding(.top, 24)
                                .padding(.bottom, -1)
                                .foregroundColor(Color(.systemBackground))
                        )
                    )
                }
            }
        }
        .imagesPicker(isPresented: $openPhotosPicker, selection: $selectedItems, error: $imagePickingError,
                      maxSelectionCount: 1)
        .onValueChanged(of: selectedItems) {
            attachment = $0.first.map { .image($0) }
        }
        .onValueChanged(of: attachment) {
            switch $0 {
            case .image: break
            default: selectedItems = []
            }
        }
    }
}

#Preview {
    ContentView(isLoading: false, text: .constant(""), attachment: .constant(nil),
                textError: nil, pictureError: nil, pollError: nil,
                userAvatar: .defaultImage(name: "toto"),
                selectedTopic: nil, showTopicPicker: .constant(false), createPoll: { })
}
