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
    @Environment(\.trackingApi) private var trackingApi

    @Compat.StateObject private var viewModel: CreatePostViewModel

    @State private var showTopicPicker = false
    @State private var showChangesWillBeLostAlert = false

    private let canClose: Bool
    private let navBarLeadingAction: OctopusNavBarLeadingAction?

    init(octopus: OctopusSDK,
         withPoll: Bool,
         defaultTopicId: String?,
         defaultText: String? = nil,
         defaultImage: Data? = nil,
         cta: WritableCTA? = nil,
         creationSource: PostsRepository.CreationSource = .user,
         bridgeShareSignature: (@Sendable (_ fingerprint: String) async throws -> String)? = nil,
         canClose: Bool = false,
         navBarLeadingAction: OctopusNavBarLeadingAction? = nil) {
        _viewModel = Compat.StateObject(wrappedValue: CreatePostViewModel(
            octopus: octopus,
            withPoll: withPoll,
            defaultTopicId: defaultTopicId,
            defaultText: defaultText,
            defaultImage: defaultImage,
            cta: cta,
            creationSource: creationSource,
            bridgeShareSignature: bridgeShareSignature))
        self.canClose = canClose
        self.navBarLeadingAction = navBarLeadingAction
    }

    /// Leaves the composer: runs the host leading action when provided, otherwise dismisses the SwiftUI
    /// presentation (which pops it when pushed, or dismisses it when presented modally).
    private func leaveScreen() {
        if let navBarLeadingAction {
            navBarLeadingAction.onTap()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    var body: some View {
        ContentView(isLoading: viewModel.isLoading,
                    // Implicit legal footer only in implicit mode; explicit modes use the consent sheet.
                    displayCguText: !viewModel.userHasAcceptedCgu && viewModel.sendButtonAvailable
                        && !viewModel.termsAcceptanceMode.isExplicit,
                    text: $viewModel.text,
                    image: $viewModel.image,
                    poll: $viewModel.poll,
                    textError: viewModel.textError,
                    pictureError: viewModel.pictureError,
                    pollError: viewModel.pollError,
                    termsOfUseUrl: viewModel.termsOfUseUrl, privacyPolicyUrl: viewModel.privacyPolicyUrl,
                    communityGuidelinesUrl: viewModel.communityGuidelinesUrl,
                    consentTexts: viewModel.consentTexts,
                    userAvatar: viewModel.userAvatar ?? .defaultImage(name: "?"),
                    selectedTopic: viewModel.selectedTopic,
                    showTopicPicker: $showTopicPicker,
                    picturesEnabled: viewModel.picturesEnabled,
                    pollsEnabled: viewModel.pollsEnabled,
                    createPoll: viewModel.createPoll)
        // Fill the whole screen (including safe areas) with the community background: the form already
        // paints some of its parts with that color (text-area tap zone, action bar), so without it the
        // screen mixes the custom color with the system background.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .largeScreenMarginBackground()
        .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction,
                          onNicknameChoiceClosed: viewModel.nicknameChoiceClosed)
        .navigationBarTitle(Text("Post.Create.Title", bundle: .module), displayMode: .inline)
        .navigationBarBackButtonHidden(viewModel.hasChanges || canClose || navBarLeadingAction != nil)
        .toolbar(leading: leadingBarItem, trailing: postButton,
                 trailingSharedBackgroundVisibility: .hidden)
        .octopusFullScreenCover(isPresented: $showTopicPicker) {
            GroupListScreen(octopus: viewModel.octopus, context: .groupSelection(
                selectedGroupId: viewModel.selectedTopic?.topicId,
                updateSelectedGroupId: { newTopicId in
                    viewModel.selectedTopic = viewModel.topics.first(where: { $0.topicId == newTopicId })
                    showTopicPicker = false
                }))
        }

        .errorAlert(viewModel.$alertError, onDismiss: { viewModel.alertError = nil })
        .destructiveConfirmationAlert(
            "Common.CancelModifications",
            isPresented: $showChangesWillBeLostAlert,
            cancelLabel: "Common.No",
            destructiveLabel: "Common.Yes",
            action: { leaveScreen() })
        .emitScreenDisplayed(.createPost, trackingApi: trackingApi)
        .termsConsentSheet(
            isPresented: $viewModel.displayConsentSheet,
            mode: viewModel.termsAcceptanceMode,
            consentTexts: viewModel.consentTexts,
            contribution: .post,
            termsUrl: viewModel.termsOfUseUrl,
            privacyUrl: viewModel.privacyPolicyUrl,
            rulesUrl: viewModel.communityGuidelinesUrl,
            onAccept: { viewModel.acceptConsentAndSend() })
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            presentationMode.wrappedValue.dismiss()
        }
    }

    @ViewBuilder
    private var leadingBarItem: some View {
        if let navBarLeadingAction {
            NavBarLeadingActionButton(navBarLeadingAction, onTap: {
                if viewModel.hasChanges {
                    showChangesWillBeLostAlert = true
                } else {
                    navBarLeadingAction.onTap()
                }
            })
        } else if canClose && viewModel.hasChanges {
            CloseButton(action: { showChangesWillBeLostAlert = true })
        } else if canClose && !viewModel.hasChanges {
            CloseButton(action: { presentationMode.wrappedValue.dismiss() })
        } else if !canClose && viewModel.hasChanges {
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
                    HapticFeedback.play()
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
    @Binding var image: ImageAndData?
    @Binding var poll: EditablePoll?

    let textError: DisplayableString?
    let pictureError: DisplayableString?
    let pollError: DisplayableString?

    let termsOfUseUrl: URL
    let privacyPolicyUrl: URL
    let communityGuidelinesUrl: URL
    let consentTexts: ConsentTexts?

    let userAvatar: Author.Avatar
    let selectedTopic: CreatePostViewModel.DisplayableTopic?

    @Binding var showTopicPicker: Bool
    let picturesEnabled: Bool
    let pollsEnabled: Bool
    let createPoll: () -> Void

    var body: some View {
        WritingPostForm(displayCguText: displayCguText, text: $text, image: $image, poll: $poll,
                        textError: textError, pictureError: pictureError, pollError: pollError,
                        termsOfUseUrl: termsOfUseUrl, privacyPolicyUrl: privacyPolicyUrl,
                        communityGuidelinesUrl: communityGuidelinesUrl,
                        consentTexts: consentTexts,
                        userAvatar: userAvatar, selectedTopic: selectedTopic,
                        showTopicPicker: $showTopicPicker,
                        picturesEnabled: picturesEnabled,
                        pollsEnabled: pollsEnabled,
                        createPoll: createPoll)
        .disabled(isLoading)
    }
}

private struct WritingPostForm: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var languageManager: LanguageManager
    let displayCguText: Bool

    @Binding var text: String
    @Binding var image: ImageAndData?
    @Binding var poll: EditablePoll?

    let textError: DisplayableString?
    let pictureError: DisplayableString?
    let pollError: DisplayableString?

    let termsOfUseUrl: URL
    let privacyPolicyUrl: URL
    let communityGuidelinesUrl: URL
    let consentTexts: ConsentTexts?

    let userAvatar: Author.Avatar
    let selectedTopic: CreatePostViewModel.DisplayableTopic?
    @Binding var showTopicPicker: Bool
    let picturesEnabled: Bool
    let pollsEnabled: Bool
    let createPoll: () -> Void

    @State private var selectedItems: [ImageAndData] = []
    @State private var imagePickingError: Error?
    @State private var textFocused = true
    @State private var openPhotosPicker = false
    @State private var scrollToBottomOfId: String?
    @State private var attachmentScrollRequest: Compat.ScrollRequest?
    /// The block the user is adding: set by the user action, consumed by the next change of that block.
    @State private var pendingReveal: AttachmentBlock?
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var imagePreviewHeight: CGFloat = 0
    @State private var pollEditorHeight: CGFloat = 0

    @State private var keyboardHeight: CGFloat = 0
    @State private var previousText = ""

    private enum AttachmentBlock: String {
        case imagePreview
        case pollEditor
    }

    private var attachmentRules: CreatePostAttachmentRules {
        CreatePostAttachmentRules(picturesEnabled: picturesEnabled, pollsEnabled: pollsEnabled,
                                  hasImage: image != nil, hasPoll: poll != nil)
    }

    /// The notice under the composer: the community's own when it set one for the implicit mode, the SDK wording
    /// otherwise. Resolved for the implicit mode because the notice only shows in that mode (`displayCguText`).
    var implicitNotice: String {
        ConsentWording.implicitNotice(texts: consentTexts,
                                      urls: ConsentLegalUrls(terms: termsOfUseUrl, privacy: privacyPolicyUrl,
                                                             rules: communityGuidelinesUrl),
                                      locale: languageManager.overridenLocale)
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.white.opacity(0.0001)
                .frame(maxWidth: .infinity)
                .frame(height: 1)
            Compat.ScrollView(scrollToId: $scrollToBottomOfId, idAnchor: .bottom,
                              scrollRequest: $attachmentScrollRequest) {
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
                                    IconImage(theme.assets.icons.content.post.creation.topicSelection)
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

                            if let imageAndData = image {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: imageAndData.image)
                                        .resizable()
                                        .scaledToFit()
                                    Button(action: {
                                        image = nil
                                        selectedItems = []
                                    }) {
                                        IconImage(theme.assets.icons.content.post.creation.deletePicture)
                                            .font(theme.fonts.body1)
                                            .padding(10)
                                            .foregroundColor(theme.colors.gray500)
                                            .background(
                                                Circle()
                                                    .foregroundColor(theme.colors.gray200)

                                            )
                                            .frame(minWidth: 32, minHeight: 32)
                                            .padding([.leading, .bottom], 14)
                                            .padding([.trailing, .top], 4)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabelInBundle("Accessibility.Image.Delete")
                                }
                                // The gap above the block is part of the revealed area, so a tall block aligned
                                // on its top keeps it.
                                .padding(.top, 10)
                                .readHeight($imagePreviewHeight)
                                .id(AttachmentBlock.imagePreview.rawValue)
                            }
                            if let editablePoll = poll {
                                CreatePollView(
                                    poll: Binding(get: { editablePoll }, set: { poll = $0 }),
                                    deletePoll: {
                                        poll = nil
                                    })
                                .padding(.top, 10)
                                .readHeight($pollEditorHeight)
                                .id(AttachmentBlock.pollEditor.rawValue)
                            }
                            if attachmentRules.hasNoAttachment && text.isEmpty {
                                // when there is no attachment displayed, use the remaining part of the screen to
                                // catch tap
                                theme.colors.background
                                    .frame(height: 150)
                                    .onTapGesture {
                                        textFocused = true
                                    }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .readHeight($scrollViewportHeight)
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
                    if attachmentRules.showsActionBar {
                        HStack(spacing: 8) {
                            // Hide the picture-add entry when the community disables post pictures.
                            if attachmentRules.canAddPicture {
                                Button(action: { openPhotosPicker = true }) {
                                    HStack(spacing: 4) {
                                        IconImage(theme.assets.icons.content.post.creation.addPicture)
                                        Text("Content.Create.AddPicture", bundle: .module)
                                    }
                                }
                                .buttonStyle(OctopusButtonStyle(.mid, style: .outline, hasLeadingIcon: true,
                                                                externalVerticalPadding: 16))
                            }
                            // Hide the poll-creation entry when the community disables polls or a poll exists.
                            if attachmentRules.canAddPoll {
                                Button(action: {
                                    markForReveal(.pollEditor)
                                    // Not animated: an animated insertion animates the scroll content size
                                    // from "fits", which clamps the reveal to 0.
                                    createPoll()
                                }) {
                                    HStack(spacing: 4) {
                                        IconImage(theme.assets.icons.content.post.creation.addPoll)
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
                            .foregroundColor(theme.colors.background)
                            .overlay(
                                Rectangle()
                                    .padding(.top, 24)
                                    .padding(.bottom, -1)
                                    .foregroundColor(theme.colors.background)
                            )
                        )
                    }

                    if displayCguText {
                        theme.colors.gray300.frame(height: 1)
                        ImplicitConsentNotice(markdown: implicitNotice)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: displayCguText)
            }
        }
        .imagesPicker(isPresented: $openPhotosPicker, selection: $selectedItems, error: $imagePickingError,
                      maxSelectionCount: 1)
        .onValueChanged(of: selectedItems) { newItems in
            if newItems.first != nil {
                markForReveal(.imagePreview)
            }
            image = newItems.first
        }
        .onValueChanged(of: image) { newImage in
            if newImage == nil {
                selectedItems = []
            }
            revealIfPending(.imagePreview, blockExists: newImage != nil)
        }
        .onValueChanged(of: poll != nil) {
            revealIfPending(.pollEditor, blockExists: $0)
        }
    }

    /// Marks the block the user is adding so it is revealed once inserted. Skipped below iOS 14: there is no
    /// programmatic scroll there, and `onValueChanged` fires on every render, which would keep re-marking it.
    private func markForReveal(_ block: AttachmentBlock) {
        if #available(iOS 14.0, *) {
            pendingReveal = block
        }
    }

    /// Scrolls the minimum amount that makes the block the user just added visible; a block taller than the
    /// visible area is aligned on its top instead. Does nothing unless `pendingReveal` marks this block, so a
    /// prefilled image, a poll created at init and poll edits never scroll. Runs from the update that inserts
    /// the block, then hops to the next main-queue turn so the block is laid out (and measured) first.
    private func revealIfPending(_ block: AttachmentBlock, blockExists: Bool) {
        guard pendingReveal == block else { return }
        pendingReveal = nil
        guard blockExists else { return }
        DispatchQueue.main.async {
            let blockHeight: CGFloat
            switch block {
            case .imagePreview: blockHeight = imagePreviewHeight
            case .pollEditor: blockHeight = pollEditorHeight
            }
            let alignsTop = CreatePostAttachmentRules.revealAlignsTop(blockHeight: blockHeight,
                                                                      viewportHeight: scrollViewportHeight)
            attachmentScrollRequest = Compat.ScrollRequest(id: block.rawValue, anchor: alignsTop ? .top : nil)
        }
    }
}

#Preview {
    ContentView(isLoading: false, displayCguText: true, text: .constant(""),
                image: .constant(ImageAndData(imageData: Data(), image: .actions)),
                poll: .constant(EditablePoll()),
                textError: nil, pictureError: nil, pollError: nil,
                termsOfUseUrl: URL(string: "www.google.com")!,
                privacyPolicyUrl: URL(string: "www.google.com")!,
                communityGuidelinesUrl: URL(string: "www.google.com")!,
                consentTexts: nil,
                userAvatar: .defaultImage(name: "toto"),
                selectedTopic: nil, showTopicPicker: .constant(false),
                picturesEnabled: true, pollsEnabled: true, createPoll: { })
}
