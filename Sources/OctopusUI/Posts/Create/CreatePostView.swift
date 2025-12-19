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
    @State private var showChangesWillBeLostAlert = false

    init(octopus: OctopusSDK, withPoll: Bool) {
        _viewModel = Compat.StateObject(wrappedValue: CreatePostViewModel(octopus: octopus, withPoll: withPoll))
    }

    var body: some View {
        ContentView(isLoading: viewModel.isLoading,
                    displayCguText: !viewModel.userHasAcceptedCgu && viewModel.sendButtonAvailable,
                    text: $viewModel.text,
                    attachment: $viewModel.attachment,
                    textError: viewModel.textError,
                    pictureError: viewModel.pictureError,
                    pollError: viewModel.pollError,
                    termsOfUseUrl: viewModel.termsOfUseUrl, privacyPolicyUrl: viewModel.privacyPolicyUrl,
                    communityGuidelinesUrl: viewModel.communityGuidelinesUrl,
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
            TopicPicker(topics: viewModel.topics, selectedTopic: $viewModel.selectedTopic)
                .sizedSheet()
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
            .buttonStyle(OctopusButtonStyle(.mid, enabled: viewModel.sendButtonAvailable,
                                            externalVerticalPadding: 5))
            .disabled(!viewModel.sendButtonAvailable)
        } else {
            if #available(iOS 14.0, *) {
                ProgressView()
            } else {
                Button(action: { }) {
                    Text("Post.Create.Button", bundle: .module)
                }
                .buttonStyle(OctopusButtonStyle(.mid, enabled: true,
                                                externalVerticalPadding: 5))
                .disabled(true)
            }
        }
    }
}

private struct ContentView: View {
    let isLoading: Bool
    let displayCguText: Bool
    @Binding var text: String
    @Binding var attachment: CreatePostViewModel.Attachment?

    let textError: DisplayableString?
    let pictureError: DisplayableString?
    let pollError: DisplayableString?

    let termsOfUseUrl: URL
    let privacyPolicyUrl: URL
    let communityGuidelinesUrl: URL

    let userAvatar: Author.Avatar
    let selectedTopic: CreatePostViewModel.DisplayableTopic?

    @Binding var showTopicPicker: Bool
    let createPoll: () -> Void

    var body: some View {
        WritingPostForm(displayCguText: displayCguText, text: $text, attachment: $attachment,
                        textError: textError, pictureError: pictureError, pollError: pollError,
                        termsOfUseUrl: termsOfUseUrl, privacyPolicyUrl: privacyPolicyUrl,
                        communityGuidelinesUrl: communityGuidelinesUrl,
                        userAvatar: userAvatar, selectedTopic: selectedTopic,
                        showTopicPicker: $showTopicPicker,
                        createPoll: createPoll)
        .disabled(isLoading)
    }
}

private struct WritingPostForm: View {
    @Environment(\.octopusTheme) private var theme
    let displayCguText: Bool

    @Binding var text: String
    @Binding var attachment: CreatePostViewModel.Attachment?

    let textError: DisplayableString?
    let pictureError: DisplayableString?
    let pollError: DisplayableString?

    let termsOfUseUrl: URL
    let privacyPolicyUrl: URL
    let communityGuidelinesUrl: URL

    let userAvatar: Author.Avatar
    let selectedTopic: CreatePostViewModel.DisplayableTopic?
    @Binding var showTopicPicker: Bool
    let createPoll: () -> Void

    @State private var selectedItems: [ImageAndData] = []
    @State private var imagePickingError: Error?
    @State private var textFocused = true
    @State private var openPhotosPicker = false
    @State private var scrollToBottomOfId: String?

    @State private var keyboardHeight: CGFloat = 0
    @State private var previousText = ""

    var legalTextStr: String {
        if #available(iOS 15, *) {
            return String(
                localized: "Content.Create.Legal_termOfUse:\(termsOfUseUrl.absoluteString)_privacyPolicy:\(privacyPolicyUrl.absoluteString)_communityGuidelines:\(communityGuidelinesUrl.absoluteString)",
                bundle: .module)
        } else {
            return NSLocalizedString(
                "Content.Create.Legal_termOfUse:\(termsOfUseUrl.absoluteString)_privacyPolicy:\(privacyPolicyUrl.absoluteString)_communityGuidelines:\(communityGuidelinesUrl.absoluteString)",
                bundle: .module,
                comment: "")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.white.opacity(0.0001)
                .frame(maxWidth: .infinity)
                .frame(height: 1)
            Compat.ScrollView(scrollToId: $scrollToBottomOfId, idAnchor: .bottom) {
                VStack {
                    VStack(alignment: .leading) {
                        HStack(spacing: 8) {
                            AuthorAvatarView(avatar: userAvatar)
                                .frame(width: 32, height: 32)

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
                            .buttonStyle(OctopusButtonStyle(.mid, style: .secondary, hasTrailingIcon: true,
                                                            externalVerticalPadding: 5))
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            OctopusTextField(text: $text, placeholder: "Post.Create.Text.Placeholder")
                                .focused($textFocused)
                                .id("textInputView")
                                .onValueChanged(of: text) { newValue in
                                    // only scroll to bottom if the last line changed
                                    let previousLastLine = previousText.trimmingCharacters(in: .whitespacesAndNewlines)
                                        .components(separatedBy: "\n").last ?? ""
                                    let newLastLine = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        .components(separatedBy: "\n").last ?? ""
                                    if previousLastLine != newLastLine {
                                        scrollToBottomOfId = "textInputView"
                                    }
                                    previousText = newValue
                                }
                                .padding(.top, 24)
                                .padding(.bottom, 2)
                                .onTapGesture { textFocused = true }
                                .modify {
                                    if #available(iOS 16.0, *) {
                                        $0.scrollDisabled(true)
                                    } else { $0 }
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
                                            .padding([.leading, .bottom], 14)
                                            .padding([.trailing, .top], 4)

                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabelInBundle("Accessibility.Image.Delete")
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
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
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

                VStack(spacing: 0) {
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
                                .buttonStyle(OctopusButtonStyle(.mid, style: .outline, hasLeadingIcon: true,
                                                                externalVerticalPadding: 16))
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
                                .buttonStyle(OctopusButtonStyle(.mid, style: .outline, hasLeadingIcon: true,
                                                               externalVerticalPadding: 16))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
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

                    if displayCguText {
                        theme.colors.gray300.frame(height: 1)
                        RichText(legalTextStr)
                            .font(theme.fonts.caption2.weight(.medium))
                            .foregroundColor(theme.colors.gray900)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: displayCguText)
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
    ContentView(isLoading: false, displayCguText: true, text: .constant(""), attachment: .constant(.image(ImageAndData(imageData: Data(), image: .actions))),
                textError: nil, pictureError: nil, pollError: nil,
                termsOfUseUrl: URL(string: "www.google.com")!,
                privacyPolicyUrl: URL(string: "www.google.com")!,
                communityGuidelinesUrl: URL(string: "www.google.com")!,
                userAvatar: .defaultImage(name: "toto"),
                selectedTopic: nil, showTopicPicker: .constant(false), createPoll: { })
}
