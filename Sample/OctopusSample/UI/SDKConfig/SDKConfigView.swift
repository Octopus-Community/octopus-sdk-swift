//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// View that display the SDK Configuration. Internal use only.
struct SDKConfigScreen: View {
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            SDKConfigView(afterSaveAction: {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct SDKConfigView: View {
    let afterSaveAction: () -> Void

    @StateObjectCompat private var viewModel = SDKConfigViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.accentColor)
                    Text("Authentication mode")
                        .font(.subheadline).bold()
                }
                Picker("", selection: $viewModel.authMode) {
                    Text("Octopus").tag(SDKConfigViewModel.AuthMode.octopus)
                    Text("SSO").tag(SDKConfigViewModel.AuthMode.sso)
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            if viewModel.authMode == .sso {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.text.rectangle")
                            .foregroundColor(.accentColor)
                        Text("Associated Fields")
                            .font(.subheadline).bold()
                    }
                    Toggle(isOn: $viewModel.nicknameIsAssociated) {
                        Text("Nickname")
                    }
                    Toggle(isOn: $viewModel.bioIsAssociated) {
                        Text("Bio")
                    }
                    Toggle(isOn: $viewModel.pictureIsAssociated) {
                        Text("Picture")
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                if !viewModel.nicknameIsAssociated {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.accentColor)
                            Text("Security")
                                .font(.subheadline).bold()
                        }
                        Toggle(isOn: $viewModel.forceLoginOnStringAction) {
                            Text("Force login on strong actions")
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                }
            }

            if viewModel.canSave {
                Spacer()
                Button(action: {
                    viewModel.save()
                    afterSaveAction()
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Save")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
            } else {
                Text("No existing community to match this configuration")
                    .font(.subheadline)
                    .foregroundColor(Color.red)
                Spacer()
            }
        }
        .navigationBarTitle(Text("SDK Configuration"))
        .padding()
    }
}
