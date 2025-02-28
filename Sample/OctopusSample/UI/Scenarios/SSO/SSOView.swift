//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusUI

/// View that lets you see how to configure the sdk in SSO mode.
///
/// SampleModel is used to reconfigure the SDK
/// SSOViewModel keeps track of the app's current user and let's you edit its profile.
/// Whenever the app user changes, the view model informs the SDK about this change and you should do that in your app
/// too.
struct SSOView: View {
    @ObservedObject var model: SampleModel
    @StateObjectCompat private var viewModel: SSOViewModel

    @State private var showModal = false
    @State private var showLogin = false
    @State private var showEditProfileWithAge = false
    @State private var appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField> = []

    init(model: SampleModel) {
        self.model = model
        self._viewModel = StateObjectCompat(wrappedValue: SSOViewModel(model: model))
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("SDK Config:")
                .font(.headline)
            Text("App managed fields:")
            SSOAppManagedProfileFieldsSelectionView(appManagedFields: $viewModel.appManagedFields)
            Text("If a field is selected, the corresponding info in the profile won't be editable in the SDK.")
                .font(.caption)
            Text("If a field is not selected, the corresponding info in the client profile will only be used as " +
                 "suggested value when the Octopus profile is created.")
            .font(.caption)
            Spacer().frame(height: 30)
            Text("Client User Config:")
                .font(.headline)
            VStack {
                if viewModel.appUser == nil {
                    Button("Login") {
                        showLogin = true
                    }
                } else {
                    Button("Edit user") {
                        showEditProfileWithAge = true
                    }
                    Button("Logout") {
                        viewModel.appUser = nil
                    }
                }
            }.frame(maxWidth: .infinity)
            Spacer()
            Button("Open Octopus") {
                showModal = true
            }.frame(maxWidth: .infinity)
            Spacer().frame(height: 50)
        }
        .padding()
        .fullScreenCover(isPresented: $showModal) {
            // Display the UI of the sdk and whenever the SDK asks for login screen or edit profile screens,
            // display them
            OctopusHomeScreen(octopus: model.octopus)
                .fullScreenCover(isPresented: $viewModel.openLogin) {
                    AppLoginScreen(appUser: $viewModel.appUser)
                }
                .fullScreenCover(isPresented: $viewModel.openEditProfile) {
                    AppEditUserScreen(appUser: $viewModel.appUser, displayAge: false)
                }
        }
        .fullScreenCover(isPresented: $showLogin) {
            AppLoginScreen(appUser: $viewModel.appUser)
        }
        .fullScreenCover(isPresented: $showEditProfileWithAge) {
            AppEditUserScreen(appUser: $viewModel.appUser, displayAge: true)
        }
        .onAppear() {
            viewModel.onAppear()
        }
        .onDisappear() {
            viewModel.onDisappear()
        }
    }
}

private struct SSOAppManagedProfileFieldsSelectionView: View {
    @Binding var appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProfileFieldsSelectionView(appManagedFields: $appManagedFields, field: .nickname)
            ProfileFieldsSelectionView(appManagedFields: $appManagedFields, field: .bio)
            ProfileFieldsSelectionView(appManagedFields: $appManagedFields, field: .picture)
        }
    }
}

private struct ProfileFieldsSelectionView: View {
    @Binding var appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>
    let field: ConnectionMode.SSOConfiguration.ProfileField

    @State private var isOn: Bool = false

    var body: some View {
        Button(action: {
            if appManagedFields.contains(field) {
                appManagedFields.remove(field)
            } else {
                appManagedFields.insert(field)
            }
        }) {
            HStack {
                Image(appManagedFields.contains(field) ? .CheckBox.on : .CheckBox.off)
                Text(field.displayName)
                Spacer()
            }.accentColor(Color.primary)
        }.frame(maxWidth: .infinity)
    }
}

extension ConnectionMode.SSOConfiguration.ProfileField {
    var displayName: String {
        return switch self {
        case .nickname: "Nickname"
        case .bio: "Bio"
        case .picture: "Picture"
        }
    }
}

