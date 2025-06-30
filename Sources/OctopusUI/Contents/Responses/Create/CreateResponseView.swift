//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct CreateResponseView: View {
    let responseKind: ResponseKind
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
            responseKind: responseKind, isLoading: isLoading, sendAvailable: sendAvailable,
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
        .compatAlert(
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
        HStack(alignment: .bottom, spacing: 8) {
            Button(action: {
                removeFocus()
                openPhotosPicker = true
            }) {
                Image(.addMedia)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(OctopusButtonStyle(.small(.outline), hasLeadingIcon: true, hasTrailingIcon: true))

            OctopusInput(error: pictureError ?? textError, isFocused: textFocused) {
                VStack(alignment: .leading, spacing: 4) {

                    OctopusTextField(text: $text,
                                     placeholder: responseKind.createTextPlaceholder,
                                     lineLimit: picture != nil ? 4 : 5)
                    .focused($textFocused)

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
            }

            Button(action: {
                removeFocus()
                send()
            }) {
                HStack(spacing: 8) {
                    if isLoading {
                        Compat.ProgressView(tint: theme.colors.onPrimary)
                    } else {
                        Image(.send)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .buttonStyle(OctopusButtonStyle(.mid(.main), enabled: sendAvailable && !isLoading,
                                            hasLeadingIcon: true, hasTrailingIcon: true))
            .disabled(!sendAvailable || isLoading)
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

    private func removeFocus() {
        textFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private extension ResponseKind {
    var createTextPlaceholder: LocalizedStringKey {
        switch self {
        case .comment: "Comment.Create.Text.Placeholder"
        case .reply: "Reply.Create.Text.Placeholder"
        }
    }
}
