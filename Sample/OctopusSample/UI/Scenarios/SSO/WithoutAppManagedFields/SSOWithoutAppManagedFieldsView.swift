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
/// SSOViewModel keeps track of the app's current user and let's you edit its profile.
/// Whenever the app user changes, the view model informs the SDK about this change and you should do that in your app
/// too.
struct SSOWithoutAppManagedFieldsView: View {
    @StateObjectCompat private var viewModel = SSOWithoutAppManagedFieldsViewModel()

    @State private var showModal = false
    @State private var showLogin = false
    @State private var showEditProfileWithAge = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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
            OctopusHomeScreen(octopus: viewModel.octopus!)
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
        .navigationBarTitle(Text("No App Managed Fields"), displayMode: .inline)
    }
}
