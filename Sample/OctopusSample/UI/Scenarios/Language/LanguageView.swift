//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that displays a list of language in order to set them as Octopus language.
/// Some apps do not use the default way of handling the language which provide the system/app defined language by the
/// user. If you have a custom setting inside your app that does not set the system AppLanguage, you can call a function
/// of Octopus in order to customize the language used (so Octopus does not use the system language but yours instead).
struct LanguageView: View {
    @StateObjectCompat private var viewModel = LanguageViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Select the language by tapping on the name.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                VStack(spacing: 0) {
                    ForEach(viewModel.languages.indices, id: \.self) { index in
                        let language = viewModel.languages[index]
                        Button(action: { viewModel.set(language: language) }) {
                            HStack {
                                Image(systemName: viewModel.selectedLanguage == language ?
                                      "checkmark.circle.fill" : "circle")
                                    .foregroundColor(
                                        viewModel.selectedLanguage == language ? .accentColor : .secondary)
                                VStack(spacing: 2) {
                                    Text(language.name)
                                        .bold()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(language.comment)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < viewModel.languages.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal)
            }
        }
    }
}
