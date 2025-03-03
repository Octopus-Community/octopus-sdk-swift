//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct DateTextField: View {
    @Environment(\.octopusTheme) private var theme
    /// View Properties
    @State private var viewID: String = UUID().uuidString
    @Binding var date: Date
    let text: String
    @State private var isFocused = false
    let doneAction: () -> Void
    var body: some View {
        TextField(viewID, text: .constant(text))
            .focused($isFocused)
            .modify { view in
                if #available(iOS 15.0, *) {
                    view.toolbar {
                        ToolbarItem(placement: .keyboard) {
                            if isFocused {
                                Button(action: {
                                    withAnimation {
                                        isFocused = false
                                    }
                                    doneAction()
                                }) {
                                    Text("Common.Done", bundle: .module)
                                        .foregroundColor(theme.colors.accent)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                EmptyView()
                            }
                        }
                    }
                } else {
                    view
                }
            }
            .overlay(
                TextFieldWithInputView(id: viewID) {
                    // SwiftUI Date Picker
                    DatePicker(String(""), selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.wheel)
                }
                .onTapGesture {
                    withAnimation {
                        isFocused = true
                    }
                }
            )
    }
}

fileprivate struct TextFieldWithInputView<Content: View>: UIViewRepresentable {
    var id: String
    @ViewBuilder var content: Content

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        view.executeOnWindow(maxAttempts: 10) { window in
            let textField = window.firstSubview(matching: {
                guard let textField = $0 as? UITextField else { return false }
                return textField.placeholder == id
            })
            if let textField = textField as? UITextField {
                textField.tintColor = .clear

                //Converting SwiftUI View to UIKit View
                let hostView = UIHostingController(rootView: content).view!
                hostView.frame.size = hostView.intrinsicContentSize
                /// Adding as InputView
                textField.inputView = hostView
                textField.reloadInputViews()
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) { }
}


fileprivate extension UIView {
    func firstSubview(matching: (UIView) -> Bool) -> UIView? {
        for view in subviews {
            if matching(view) {
                return view
            } else if let matchingView = view.firstSubview(matching: matching) {
                return matchingView
            }
        }
        return nil
    }

    func executeOnWindow(maxAttempts: Int, execute: @escaping (UIWindow) -> Void) {
        if let window {
            execute(window)
        } else if maxAttempts > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.executeOnWindow(maxAttempts: maxAttempts - 1, execute: execute)
            }
        }
    }
}
