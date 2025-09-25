//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusUI

/// View that mimics the Account part of your app: it handles the user connection and let the user modify its profile
struct AccountView: View {
    @StateObjectCompat private var viewModel = AccountViewModel()

    @State private var showModal = false
    @State private var showLogin = false
    @State private var showEditProfile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("App User Config:")
                .font(.headline)
            VStack {
                if viewModel.appUser == nil {
                    Button("Login") {
                        showLogin = true
                    }
                } else {
                    Button("Edit user") {
                        showEditProfile = true
                    }
                    Button("Logout") {
                        viewModel.appUser = nil
                    }
                }
            }.frame(maxWidth: .infinity)
            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $showLogin) {
            AppLoginScreen()
        }
        .fullScreenCover(isPresented: $showEditProfile) {
            AppEditUserScreen()
        }
        .navigationBarTitle(Text("Some App Managed Fields"), displayMode: .inline)
    }
}
