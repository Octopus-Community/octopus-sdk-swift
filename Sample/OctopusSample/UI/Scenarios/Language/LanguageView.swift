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
                    .padding()
                    .padding(.bottom, 8)
                ForEach(viewModel.languages.indices, id: \.self) { index in
                    let language = viewModel.languages[index]
                    Button(action: { viewModel.set(language: language) }) {
                        HStack {
                            VStack(spacing: 4) {
                                Text(language.name)
                                    .bold()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(language.comment)
                                    .font(.callout)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .multilineTextAlignment(.leading)

                            Text("\(viewModel.selectedLanguage == language ? "✅" : "✔️")")
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Color.gray.opacity(0.5).frame(height: 1)
                }
            }
        }
    }
}


