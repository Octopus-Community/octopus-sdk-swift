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

    @State private var email: String = ""
    @State private var nickname: String = ""
    @State private var bio: String = ""
    @State private var picture: Data?

    @State private var emailEmptyError = false

    var body: some View {
        NavigationView {
            VStack {
                Spacer().frame(height: 50)
                Text("This is your app's login flow")
                VStack(alignment: .leading) {
                    Text("Email:")
                    TextField("Email", text: $email)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                }
                .padding(.horizontal)
                .padding(.top)
                AppEditUserView(nickname: $nickname, bio: $bio, picture: $picture)
                Spacer()
                Button("Login") {
                    guard !email.isEmpty else {
                        emailEmptyError = true
                        return
                    }
                    viewModel.appUser = .init(userId: email.lowercased(),
                                              nickname: nickname,
                                              bio: bio,
                                              picture: picture)
                    presentationMode.wrappedValue.dismiss()
                }
                Spacer()
            }
            .padding()
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
            }
            .modify {
                if #available(iOS 15.0, *) {
                    $0.alert(
                        Text(verbatim: "Please fill the email"),
                        isPresented: $emailEmptyError, actions: { })
                } else {
                    $0.alert(isPresented: $emailEmptyError) {
                        Alert(title: Text(verbatim: "Please fill the email"))
                    }
                }
            }
            .presentationBackground(Color(.systemBackground))
        }
    }
}
