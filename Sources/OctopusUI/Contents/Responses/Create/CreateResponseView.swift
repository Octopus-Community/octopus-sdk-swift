//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct CreateResponseView: View {
    let responseKind: ResponseKind
    let avatar: Author.Avatar
    let isLoading: Bool
    let sendAvailable: Bool
    @Binding var text: String
    @Binding var picture: ImageAndData?
    @Binding var textFocused: Bool
    let alertError: DisplayableString?
    let textError: DisplayableString?
    let pictureError: DisplayableString?

    let send: () -> Void
    let userProfileTapped: () -> Void
    let resetAlertError: () -> Void
    let ensureConnected: () -> Bool

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    var body: some View {
        ContentView(
            responseKind: responseKind, avatar: avatar, isLoading: isLoading, sendAvailable: sendAvailable,
            text: $text, picture: $picture, textFocused: $textFocused,
            textError: textError, pictureError: pictureError,
            send: {
                if ensureConnected() {
                    send()
                }
            },
            userProfileTapped: {
                if ensureConnected() {
                    userProfileTapped()
                }
            })
        .disabled(isLoading)
        .alert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
        .onValueChanged(of: alertError) { displayableError in
            guard let displayableError else { return }
            self.displayableError = displayableError
            displayError = true
        }
        .onValueChanged(of: displayError) {
            guard !$0 else { return }
            resetAlertError()
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let responseKind: ResponseKind
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
            Spacer().frame(height: 16)
            HStack(alignment: .top) {
                Button(action: userProfileTapped) {
                    AuthorAvatarView(avatar: avatar)
                }
                .buttonStyle(.plain)
                .frame(width: 33, height: 33)
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        if #available(iOS 16.0, *) {
                            TextField(String(""), text: $text, axis: .vertical)
                                .multilineTextAlignment(.leading)
                                .lineLimit(picture != nil ? 4 : 5)
                                .focused($textFocused)
                                .foregroundColor(theme.colors.gray900)
                                .placeholder(when: text.isEmpty) {
                                    Text(responseKind.createTextPlaceholder, bundle: .module)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(theme.colors.gray700)
                                }
                                .font(theme.fonts.body2)
                        } else {
                            // TODO: create a TextField that expands vertically on iOS 13
                            TextField(String(""), text: $text)
                                .multilineTextAlignment(.leading)
                                .lineLimit(picture != nil ? 4 : 5)
                                .focused($textFocused)
                                .foregroundColor(theme.colors.gray900)
                                .placeholder(when: text.isEmpty) {
                                    Text(responseKind.createTextPlaceholder, bundle: .module)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(theme.colors.gray700)
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
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(textFocused ? theme.colors.primary : theme.colors.gray300, lineWidth: 1)
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

            if textFocused || text != "" || picture != nil {

                theme.colors.gray300.frame(height: 1)
                    .padding(.top, 16)

                HStack {
                    Button(action: { openPhotosPicker = true }) {
                        HStack(spacing: 4) {
                            Image(.addMedia)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                            Text("Content.Create.AddPicture", bundle: .module)
                                .font(theme.fonts.caption1)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(theme.colors.gray900)
                        .padding(.leading, 6)
                        .padding(.trailing, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().stroke(theme.colors.gray300, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(action: {
                        textFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        send()
                    }) {
                        HStack(spacing: 8) {
                            if isLoading {
                                Compat.ProgressView(tint: theme.colors.onPrimary)
                            }
                            Text(responseKind.createButtonText, bundle: .module)
                                .font(theme.fonts.body2)
                                .fontWeight(.medium)
                                .foregroundColor(theme.colors.onPrimary)
                                .frame(minHeight: 24)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().foregroundColor(
                                sendAvailable && !isLoading ? theme.colors.primary : theme.colors.disabled)
                        )
                    }
                    .disabled(!sendAvailable || isLoading)
                    .modify {
                        if #available(iOS 17.0, *) {
                            $0.geometryGroup()
                        } else {
                            $0
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, textFocused ? 7 : 0)
            }
        }
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

private extension ResponseKind {
    var createTextPlaceholder: LocalizedStringKey {
        switch self {
        case .comment: "Comment.Create.Text.Placeholder"
        case .reply: "Reply.Create.Text.Placeholder"
        }
    }

    var createButtonText: LocalizedStringKey {
        switch self {
        case .comment: "Comment.Create.Button"
        case .reply: "Reply.Create.Button"
        }
    }
}
