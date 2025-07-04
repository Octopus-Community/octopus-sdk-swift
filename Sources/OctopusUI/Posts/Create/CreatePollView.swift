//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct EditablePoll: Equatable {
    struct Option: Equatable, Identifiable {
        /// Unique identifier for the option. Needed to avoid erasing changes when an option is deleted
        let uuid = UUID()
        var id: UUID { uuid }

        var text: String {
            didSet {
                guard text != oldValue else { return }
                switch validator.validate(pollOptionText: text) {
                case .tooShort:
                    error = .localizationKey("Error.Text.Empty")
                case .tooLong:
                    let maxLength = validator.optionTextMaxLength
                    error = .localizationKey("Error.Text.TooLong_currentLength:\(text.count)_maxLength:\(maxLength)")
                case .none:
                    error = nil
                }
            }
        }
        private(set) var error: DisplayableString?

        private let validator: Validators.Poll

        fileprivate init(validator: Validators.Poll) {
            self.validator = validator
            text = ""
            error = nil
        }

        static func == (lhs: EditablePoll.Option, rhs: EditablePoll.Option) -> Bool {
            return lhs.text == rhs.text && lhs.error == rhs.error
        }
    }

    var options: [Option]

    var canAddOptions: Bool { options.count < validator.maxOptions }
    var canRemoveOptions: Bool { options.count > validator.minOptions }

    private let validator: Validators.Poll

    init(validator: Validators.Poll) {
        self.validator = validator
        options = (0..<validator.minOptions).map { _ in Option(validator: validator) }
    }

    mutating func removeOption(at index: Int) {
        guard canRemoveOptions else { return }
        options.remove(at: index)
    }

    mutating func addOption() {
        guard canAddOptions else { return }
        options.append(Option(validator: validator))
    }

    static func == (lhs: EditablePoll, rhs: EditablePoll) -> Bool {
        return lhs.options == rhs.options
    }
}

struct CreatePollView: View {
    @Environment(\.octopusTheme) private var theme
    @Binding var poll: EditablePoll
    let deletePoll: () -> Void

    @State private var focusOptionIndex: Int? = 0

    var body: some View {
        VStack {
            VStack(spacing: 8) {
                HStack {
                    Text("Poll.Create.Title", bundle: .module)
                        .font(theme.fonts.caption1)
                        .foregroundColor(theme.colors.gray700)
                    Spacer()
                    Button(action: {
                        withAnimation {
                            deletePoll()
                        }
                    }) {
                        Image(.trash)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(theme.colors.gray900)
                    }
                }
                ForEach($poll.options) { $option in
                    let index = poll.options.firstIndex(where: { $0.id == option.id }) ?? 0
                    OptionView(
                        index: index,
                        option: $option,
                        focusIdentifier: index,
                        focus: $focusOptionIndex,
                        canDelete: poll.canRemoveOptions,
                        deleteOption: {
                            withAnimation {
                                poll.removeOption(at: index)
                            }
                        }
                    )
                }
                if poll.canAddOptions {
                    AddOptionView(addOption: {
                        withAnimation {
                            poll.addOption()
                        }
                    })
                }
            }
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(theme.colors.gray300, lineWidth: 1)
        )
        .onValueChanged(of: poll) { newValue in
            if newValue.options.count > poll.options.count  {
                focusOptionIndex = newValue.options.count - 1
            } else if newValue.options.count < poll.options.count  {
                focusOptionIndex = nil
            }
        }
    }
}

private struct OptionView: View {
    @Environment(\.octopusTheme) private var theme
    let index: Int
    @Binding var option: EditablePoll.Option
    let focusIdentifier: Int
    @Binding var focus: Int?
    let canDelete: Bool
    let deleteOption: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                OctopusTextInput(
                    text: $option.text,
                    placeholder: "Poll.Create.Option.Text.Placeholder_index:\(index+1)",
                    error: option.error,
                    lineLimit: nil,
                    isFocused: focus == focusIdentifier)
                .focused(id: focusIdentifier, $focus)
                // keep the text without any new line character
                .onValueChanged(of: option) {
                    // be sure that it is the same option. Needed in case an option has just been deleted
                    guard option.uuid == $0.uuid else { return }
                    var newText = $0.text
                    if newText.last?.isNewline == true {
                        newText.removeLast()
                        focus = nil
                    }
                    // finally, remove all the new lines (in case of a copy/paste)
                    newText.removeAll { $0.isNewline }
                    option.text = newText
                }

                Button(action: deleteOption) {
                    Image(systemName: "xmark")
                        .font(theme.fonts.body2)
                        .foregroundColor(canDelete ? theme.colors.gray900 : theme.colors.gray200)
                }
                .disabled(!canDelete)
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AddOptionView: View {
    @Environment(\.octopusTheme) private var theme

    let addOption: () -> Void

    var body: some View {
        Button(action: addOption) {
            HStack {
                Image(systemName: "plus")
                Text("Poll.Create.Option.Add", bundle: .module)
            }
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.gray700)
            .padding(.horizontal, 8)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.colors.gray300, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
