//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct EditablePoll: Equatable {
    struct Option: Equatable {
        /// Unique identifier for the option. Needed to avoid erasing changes when an option is deleted
        let uuid = UUID()

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
        options = Array(repeating: Option(validator: validator), count: validator.minOptions)
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
                    Button(action: deletePoll) {
                        Image(.trash)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(theme.colors.gray900)
                    }
                }
                ForEach(poll.options.indices, id: \.self) { pollOptionIdx in
                    OptionView(
                        index: pollOptionIdx,
                        option: $poll.options[pollOptionIdx],
                        focusIdentifier: pollOptionIdx,
                        focus: $focusOptionIndex,
                        canDelete: poll.canRemoveOptions,
                        deleteOption: { poll.removeOption(at: pollOptionIdx) })
                }
                if poll.canAddOptions {
                    AddOptionView(addOption: { poll.addOption() })
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
                Group {
                    if #available(iOS 16.0, *) {
                        TextField(String(""), text: $option.text, axis: .vertical)
                            .multilineTextAlignment(.leading)
                            .focused(id: focusIdentifier, $focus)
                            .foregroundColor(theme.colors.gray900)
                            .placeholder(when: option.text.isEmpty) {
                                Text("Poll.Create.Option.Text.Placeholder_index:\(index+1)", bundle: .module)
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(theme.colors.gray700)
                            }
                            .font(theme.fonts.body2)
                    } else {
                        // TODO: create a TextField that expands vertically on iOS 13
                        TextField(String(""), text: $option.text)
                            .multilineTextAlignment(.leading)
                            .focused(id: focusIdentifier, $focus)
                            .foregroundColor(theme.colors.gray900)
                            .placeholder(when: option.text.isEmpty) {
                                Text("Poll.Create.Option.Text.Placeholder_index:\(index+1)", bundle: .module)
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(theme.colors.gray700)
                            }
                            .font(theme.fonts.body2)
                    }
                }
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
                .padding(.horizontal, 8)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.colors.gray300, lineWidth: 1)
                )

                Button(action: deleteOption) {
                    Image(systemName: "xmark")
                        .font(theme.fonts.body2)
                        .foregroundColor(canDelete ? theme.colors.gray900 : theme.colors.gray200)
                }
                .disabled(!canDelete)
                .buttonStyle(.plain)
            }
            if let error = option.error {
                error.textView
                    .font(theme.fonts.caption2)
                    .bold()
                    .foregroundColor(theme.colors.error)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
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
                Spacer()
            }
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.gray700)
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.colors.gray300, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
