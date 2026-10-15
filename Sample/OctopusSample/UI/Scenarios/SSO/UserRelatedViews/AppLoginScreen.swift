//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Mock of your app's login screen.
/// This screen will be displayed either when the user logs in directly in your app, or when the SDK requires a logged
/// in user (see `SSOView`).
struct AppLoginScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObjectCompat private var viewModel = AppUserViewModel()

    @State private var uniqueIdentifier: String = ""
    @State private var nickname: String = ""
    @State private var bio: String = ""
    @State private var picture: Data?
    @State private var entitlements: Set<Entitlement> = []

    @State private var identifierEmptyError = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    Spacer().frame(height: 30)
                    Text("This is your app's login flow")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "person.text.rectangle")
                                .foregroundColor(SampleTokens.Colors.textSecondary)
                            Text("Unique Identifier")
                                .font(.subheadline)
                                .foregroundColor(SampleTokens.Colors.textSecondary)
                        }
                        TextField("Unique Identifier", text: $uniqueIdentifier)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    AppEditUserView(nickname: $nickname, bio: $bio, picture: $picture)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(SampleTokens.Colors.textSecondary)
                            Text("Entitlements")
                                .font(.subheadline)
                                .foregroundColor(SampleTokens.Colors.textSecondary)
                        }
                        EditEntitlementsView(selection: $entitlements)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    Button(action: {
                        guard !uniqueIdentifier.isEmpty else {
                            identifierEmptyError = true
                            return
                        }
                        AppUserManager.instance.currentEntitlements = entitlements
                        viewModel.appUser = .init(userId: uniqueIdentifier.lowercased(),
                                                  nickname: nickname,
                                                  bio: bio,
                                                  picture: picture)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Login")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(SampleTokens.Colors.buttonBackground))
                        .foregroundColor(SampleTokens.Colors.buttonText)
                    }
                    .padding(.horizontal)
                    Spacer()
                }
            }
            .padding()
            .sampleScreenBackground()
            .navigationBarTitle("App Login Flow", displayMode: .inline)
            .navigationBarItems(
                trailing:
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                    }
            )
            .onAppear {
                nickname = viewModel.appUser?.nickname ?? ""
                bio = viewModel.appUser?.bio ?? ""
                picture = viewModel.appUser?.picture
                entitlements = AppUserManager.instance.currentEntitlements
            }
            .modify {
                if #available(iOS 15.0, *) {
                    $0.alert(
                        Text(verbatim: "Please fill the unique identifier"),
                        isPresented: $identifierEmptyError, actions: { })
                } else {
                    $0.alert(isPresented: $identifierEmptyError) {
                        Alert(title: Text(verbatim: "Please fill the unique identifier"))
                    }
                }
            }
            .presentationBackground(SampleTokens.Colors.background)
            .hostAppFooter(debugConsole: false)
        }
    }
}
