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
    @State private var showEditEntitlements = false

    var body: some View {
        VStack(spacing: 20) {
            if viewModel.appUser == nil {
                Button(action: { showLogin = true }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Login")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
            } else {
                Button(action: { showEditProfile = true }) {
                    HStack {
                        Image(systemName: "pencil.circle")
                        Text("Edit user")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "key")
                            .foregroundColor(.secondary)
                        Text("Current entitlements (from SDK)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(verbatim: viewModel.entitlementsDisplay)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button(action: { showEditEntitlements = true }) {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Edit entitlements")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
                    .foregroundColor(.accentColor)
                }
                Button(action: { viewModel.appUser = nil }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Logout")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.red))
                    .foregroundColor(.red)
                }
            }
            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $showLogin) {
            AppLoginScreen()
        }
        .fullScreenCover(isPresented: $showEditProfile) {
            AppEditUserScreen()
        }
        .sheet(isPresented: $showEditEntitlements) {
            EditEntitlementsScreen()
        }
        .navigationBarTitle(Text("Some App Managed Fields"), displayMode: .inline)
        .hostAppFooter()
    }
}
