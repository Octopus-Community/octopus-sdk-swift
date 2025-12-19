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
            return lhs.text == rhs.text && lhs.error == rhs.error && lhs.uuid == rhs.uuid
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
    
    /// Add a new empty option
    /// - Returns: returns the UUID of the newly added option. Nil if the option has not been added
    mutating func addOption() -> UUID? {
        guard canAddOptions else { return nil }
        let newOption = Option(validator: validator)
        options.append(newOption)
        return newOption.id
    }

    static func == (lhs: EditablePoll, rhs: EditablePoll) -> Bool {
        return lhs.options == rhs.options
    }
}

struct CreatePollView: View {
    @Environment(\.octopusTheme) private var theme
    @Binding var poll: EditablePoll
    let deletePoll: () -> Void

    @State private var focusOptionId: UUID?

    private let internalPadding: CGFloat = 16

    init(poll: Binding<EditablePoll>, deletePoll: @escaping () -> Void) {
        self._poll = poll
        self.deletePoll = deletePoll
        _focusOptionId = State(initialValue: poll.wrappedValue.options.first?.uuid)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Poll.Create.Title", bundle: .module)
                    .font(theme.fonts.caption1)
                    .foregroundColor(theme.colors.gray700)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, internalPadding)
                Spacer()
                Button(action: {
                    withAnimation {
                        deletePoll()
                    }
                }) {
                    Image(res: .trash)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(theme.colors.gray900)
                        .accessibilityLabelInBundle("Accessibility.Poll.Delete")
                }
                .padding(.top, internalPadding)
                .padding(.vertical, (44 - 24) - internalPadding)
                .padding(.leading, (44 - 24) - internalPadding)
                .padding(.trailing, internalPadding)
            }

            ForEach(Array(poll.options.indices), id: \.self) { index in
                OptionView(
                    index: index,
                    option: $poll.options[index],
                    focus: $focusOptionId,
                    nextFocusId: poll.options.count > index + 1 ? poll.options[index + 1].uuid : nil,
                    canDelete: poll.canRemoveOptions,
                    deleteOption: {
                        withAnimation {
                            poll.removeOption(at: index)
                        }
                    }
                )
                .padding(.vertical, 4)
            }
            if poll.canAddOptions {
                AddOptionView(addOption: {
                    withAnimation {
                        let newOptionId = poll.addOption()
                        focusOptionId = newOptionId
                    }
                })
                .padding(.trailing, internalPadding)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, internalPadding)
        .padding(.leading, internalPadding)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(theme.colors.gray300, lineWidth: 1)
        )
    }
}

private struct OptionView: View {
    @Environment(\.octopusTheme) private var theme
    let index: Int
    @Binding var option: EditablePoll.Option
    @Binding var focus: UUID?
    let nextFocusId: UUID?
    let canDelete: Bool
    let deleteOption: () -> Void

    private let leadingPadding: CGFloat = 16

    var body: some View {
        HStack(spacing: 0) {
            OctopusTextInput(
                text: $option.text,
                placeholder: "Poll.Create.Option.Text.Placeholder_index:\(index+1)",
                error: option.error,
                lineLimit: nil,
                isFocused: Binding(
                    get: { focus == option.id },
                    set: {
                        if $0 {
                            focus = option.id
                        }
                    })
            )
            .focused(id: option.id, $focus)
            // keep the text without any new line character
            .onValueChanged(of: option) {
                // be sure that it is the same option. Needed in case an option has just been deleted
                guard option.uuid == $0.uuid else { return }
                var newText = $0.text
                if newText.last?.isNewline == true {
                    newText.removeLast()
                    focus = nextFocusId
                }
                // finally, remove all the new lines (in case of a copy/paste)
                newText.removeAll { $0.isNewline }
                option.text = newText
            }

            Button(action: deleteOption) {
                Image(systemName: "xmark")
                    .font(theme.fonts.body2)
                    .foregroundColor(canDelete ? theme.colors.gray900 : theme.colors.gray200)
                    .accessibilityLabelInBundle("Accessibility.Poll.Option.Delete")
                    .padding(.leading, (44 - 14) - leadingPadding)
                    .padding(.trailing, leadingPadding)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
            }
            .disabled(!canDelete)
            .buttonStyle(.plain)
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
        .frame(minHeight: 44)
    }
}
