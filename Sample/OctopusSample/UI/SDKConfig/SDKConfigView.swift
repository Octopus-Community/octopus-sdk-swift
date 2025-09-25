//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// View that display the SDK Configuration. Internal use only.
struct SDKConfigView: View {
    @Environment(\.presentationMode) private var presentationMode

    @StateObjectCompat private var viewModel = SDKConfigViewModel()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Text("Authentication mode:")
                Picker("", selection: $viewModel.authMode) {
                    Text("Octopus").tag(SDKConfigViewModel.AuthMode.octopus)
                    Text("SSO").tag(SDKConfigViewModel.AuthMode.sso)
                }
                .pickerStyle(.segmented)
                if viewModel.authMode == .sso {
                    Spacer().frame(height: 20)
                    Text("Associated Fields:")
                    Toggle(isOn: $viewModel.nicknameIsAssociated) {
                        Text("Nickname")
                    }
                    Toggle(isOn: $viewModel.bioIsAssociated) {
                        Text("Bio")
                    }
                    Toggle(isOn: $viewModel.pictureIsAssociated) {
                        Text("Picture")
                    }
                    Spacer().frame(height: 60)
                    if !viewModel.nicknameIsAssociated {
                        Toggle(isOn: $viewModel.forceLoginOnStringAction) {
                            Text("Force login on strong actions")
                        }
                    }
                }
                if viewModel.canSave {
                    Spacer()
                    Button(action: {
                        viewModel.save()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Text("No existing community to match this configuration")
                        .foregroundColor(Color.red)
                    Spacer()
                }
            }
            .navigationBarTitle(Text("SDK Configuration"))
            .padding()
        }
    }
}
