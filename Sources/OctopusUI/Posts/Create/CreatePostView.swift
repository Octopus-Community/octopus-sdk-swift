//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct CreatePostView: View {
    @Environment(\.textTone) private var textTone
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
         defaultImages: [Data] = [],
         cta: WritableCTA? = nil,
         creationSource: PostsRepository.CreationSource = .user,
         bridgeShareSignature: (@Sendable (_ fingerprint: String) async throws -> String?)? = nil,
         canClose: Bool = false,
         navBarLeadingAction: OctopusNavBarLeadingAction? = nil) {
        _viewModel = Compat.StateObject(wrappedValue: CreatePostViewModel(
            octopus: octopus,
            withPoll: withPoll,
            defaultTopicId: defaultTopicId,
            defaultText: defaultText,
            defaultImages: defaultImages,
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
                    images: $viewModel.images,
                    poll: $viewModel.poll,
                    textError: viewModel.textError,
                    pictureError: viewModel.pictureError,
                    pictureToReveal: $viewModel.pictureToReveal,
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
            textTone.key(formal: "Common.CancelModifications.Formal", informal: "Common.CancelModifications.Informal"),
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
            nicknameChoiceFollows: viewModel.consentSheetLeadsToNicknameChoice,
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
    @Binding var images: [ImageAndData]
    @Binding var poll: EditablePoll?

    let textError: DisplayableString?
    let pictureError: DisplayableString?
    @Binding var pictureToReveal: String?
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
        WritingPostForm(displayCguText: displayCguText, text: $text, images: $images, poll: $poll,
                        textError: textError, pictureError: pictureError, pictureToReveal: $pictureToReveal,
                        pollError: pollError,
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
    @Environment(\.textTone) private var textTone
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var languageManager: LanguageManager
    let displayCguText: Bool

    @Binding var text: String
    @Binding var images: [ImageAndData]
    @Binding var poll: EditablePoll?

    let textError: DisplayableString?
    let pictureError: DisplayableString?
    @Binding var pictureToReveal: String?
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
    @State private var showMaxPicturesAlert = false
    @State private var scrollToBottomOfId: String?
    @State private var attachmentScrollRequest: Compat.ScrollRequest?
    /// The block the user is adding: set by the user action, consumed by the next change of that block.
    @State private var pendingReveal: AttachmentBlock?
    /// The height of the form and of the action bar laid over (or under) its bottom: the part of the form the
    /// user sees is the difference.
    @State private var formHeight: CGFloat = 0
    @State private var actionBarHeight: CGFloat = 0
    @State private var imagePreviewHeight: CGFloat = 0
    @State private var pollEditorHeight: CGFloat = 0

    @State private var keyboardHeight: CGFloat = 0
    @State private var previousText = ""

    // Measured on the composer design (one point per pixel of its 393pt-wide screens).
    private static let horizontalMargin: CGFloat = 16
    private static let avatarSide: CGFloat = 40
    /// The gap between the text and the block of images or the poll editor under it.
    private static let attachmentTopGap: CGFloat = 16
    /// The gap the action bar keeps from the end of the form when it is scrolled to the bottom.
    private static let actionBarTopGap: CGFloat = 16
    /// The gap between the action bar and what is under it: the terms notice, or the keyboard.
    private static let actionBarBottomGap: CGFloat = 8

    private enum AttachmentBlock: String {
        case imagePreview
        case pollEditor
    }

    private var attachmentRules: CreatePostAttachmentRules {
        CreatePostAttachmentRules(picturesEnabled: picturesEnabled, pollsEnabled: pollsEnabled,
                                  imageCount: images.count, hasPoll: poll != nil)
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
                                .frame(width: Self.avatarSide, height: Self.avatarSide)

                            TopicSelectionButton(selectedTopicName: selectedTopic?.name, action: {
                                showTopicPicker = true
                                textFocused = false
                            })
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            OctopusTextField(
                                text: $text,
                                placeholder: textTone.key(formal: "Post.Create.Text.Placeholder.Formal",
                                                          informal: "Post.Create.Text.Placeholder.Informal"))
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
                                .padding(.top, 14)
                                .padding(.bottom, 2)
                                .onTapGesture { textFocused = true }
                                .modify {
                                    if #available(iOS 16.0, *) {
                                        $0.scrollDisabled(true)
                                    } else { $0 }
                                }

                            if !images.isEmpty {
                                CreatePostImagesStrip(
                                    images: images,
                                    showsAddMorePill: attachmentRules.showsAddMorePill,
                                    horizontalMargin: Self.horizontalMargin,
                                    pictureToReveal: $pictureToReveal,
                                    deleteImage: { index in
                                        guard images.indices.contains(index) else { return }
                                        images.remove(at: index)
                                    },
                                    addMoreImages: openPictureEntry)
                                // The gap above the block is part of the revealed area, so a tall block aligned
                                // on its top keeps it.
                                .padding(.top, Self.attachmentTopGap)
                                .readHeight($imagePreviewHeight)
                                .id(AttachmentBlock.imagePreview.rawValue)
                            }
                            if let editablePoll = poll {
                                CreatePollView(
                                    poll: Binding(get: { editablePoll }, set: { poll = $0 }),
                                    deletePoll: {
                                        poll = nil
                                    })
                                .padding(.top, Self.attachmentTopGap)
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
                    .padding(.horizontal, Self.horizontalMargin)
                    .padding(.top, 8)
                }
            }
            // Laid over the bottom of the form, which scrolls under it up to its last block. Below iOS 15, where
            // there is no safe area inset, it is laid under the form instead.
            .safeAreaInsetCompat(edge: .bottom, spacing: 0, fallback: .stackContent) { actionBar }
            .readHeight($formHeight)
            VStack(spacing: 0) {
                if pictureError != nil || textError != nil || pollError != nil {
                    theme.colors.error.frame(height: 1)
                    Spacer().frame(height: 4)

                    if let textError {
                        textError.textView(tone: textTone)
                            .font(theme.fonts.caption2)
                            .bold()
                            .foregroundColor(theme.colors.error)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        Spacer().frame(height: 4)
                    }

                    if let pictureError {
                        pictureError.textView(tone: textTone)
                            .font(theme.fonts.caption2)
                            .bold()
                            .foregroundColor(theme.colors.error)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        Spacer().frame(height: 4)
                    }

                    if let pollError {
                        pollError.textView(tone: textTone)
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
                    if displayCguText {
                        theme.colors.gray300.frame(height: 1)
                        ImplicitConsentNotice(markdown: implicitNotice)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: displayCguText)
            }
        }
        // At least 1: a `maxSelectionCount` of 0 means no limit for the system picker. The picker is not opened
        // once the post holds the maximum anyway (see `openPictureEntry`).
        .imagesPicker(isPresented: $openPhotosPicker, selection: $selectedItems, error: $imagePickingError,
                      maxSelectionCount: max(attachmentRules.remainingPictureSlots, 1))
        .onValueChanged(of: selectedItems) { newItems in
            guard !newItems.isEmpty else { return }
            markForReveal(.imagePreview)
            images = CreatePostViewModel.appending(newItems, to: images)
            // Emptied so the next pick starts from an empty selection and only brings new pictures.
            selectedItems = []
        }
        .onValueChanged(of: images.count) { imageCount in
            revealIfPending(.imagePreview, blockExists: imageCount > 0)
        }
        .compatAlert(textTone.key(formal: "Content.Create.Picture.MaxReached.Formal",
                                  informal: "Content.Create.Picture.MaxReached.Informal"), isPresented: $showMaxPicturesAlert)
        .onValueChanged(of: poll != nil) {
            revealIfPending(.pollEditor, blockExists: $0)
        }
    }

    /// The entries that add a picture or a poll, as two labelled capsules at the leading side of the composer,
    /// floating over the bottom of the form, above the terms notice (or the keyboard).
    private var actionBar: some View {
        VStack(spacing: 0) {
            if attachmentRules.showsActionBar {
                HStack(spacing: 0) {
                    ComposerActionBar(
                        // Hide the picture-add entry when the community disables post pictures.
                        canAddPicture: attachmentRules.canAddPicture,
                        // Hide the poll-creation entry when the community disables polls or a poll exists.
                        canAddPoll: attachmentRules.canAddPoll,
                        addPicture: openPictureEntry,
                        addPoll: {
                            markForReveal(.pollEditor)
                            // Not animated: an animated insertion animates the scroll content size
                            // from "fits", which clamps the reveal to 0.
                            createPoll()
                        })
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Self.horizontalMargin)
                .padding(.top, Self.actionBarTopGap)
                .padding(.bottom, Self.actionBarBottomGap)
            }
        }
        .readHeight($actionBarHeight)
    }

    /// Opens the picker for the pictures the post can still take, or explains the limit once it holds the
    /// maximum. Does nothing when the community disables pictures, whichever entry calls it.
    private func openPictureEntry() {
        guard attachmentRules.canAddPicture else { return }
        if attachmentRules.pictureEntryShowsMaxAlert {
            showMaxPicturesAlert = true
        } else {
            openPhotosPicker = true
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
                                                                      viewportHeight: formHeight - actionBarHeight)
            attachmentScrollRequest = Compat.ScrollRequest(id: block.rawValue, anchor: alignsTop ? .top : nil)
        }
    }
}

#Preview {
    ContentView(isLoading: false, displayCguText: true, text: .constant(""),
                images: .constant([ImageAndData(imageData: Data(), image: .actions)]),
                poll: .constant(EditablePoll()),
                textError: nil, pictureError: nil, pictureToReveal: .constant(nil), pollError: nil,
                termsOfUseUrl: URL(string: "www.google.com")!,
                privacyPolicyUrl: URL(string: "www.google.com")!,
                communityGuidelinesUrl: URL(string: "www.google.com")!,
                consentTexts: nil,
                userAvatar: .defaultImage(name: "toto"),
                selectedTopic: nil, showTopicPicker: .constant(false),
                picturesEnabled: true, pollsEnabled: true, createPoll: { })
}
