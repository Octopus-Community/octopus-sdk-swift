//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Mock of your app's edit profile screen.
/// This screen will be displayed either when the user edits its profile directly in your app,
/// or when it tries to edit its profile in the SDK if app managed fields is not empty. (see `SSOView`)
struct AppEditUserScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObjectCompat private var viewModel = AppUserViewModel()

    @State private var nickname: String = ""
    @State private var bio: String = ""
    @State private var picture: Data?

    var body: some View {
        NavigationView {
            VStack {
                Text("Email: \(viewModel.appUser?.userId ?? "")")
                AppEditUserView(nickname: $nickname, bio: $bio, picture: $picture)
            }
            .navigationBarTitle("Edit your profile")
            .navigationBarItems(
                leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                },
                trailing:
                    Button(action: {
                        viewModel.appUser = .init(
                            userId: viewModel.appUser?.userId ?? "",
                            nickname: nickname,
                            bio: bio,
                            picture: picture)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "checkmark")
                    }
            )
            .onAppear {
                nickname = viewModel.appUser?.nickname ?? ""
                bio = viewModel.appUser?.bio ?? ""
                picture = viewModel.appUser?.picture
            }
            .presentationBackground(Color(.systemBackground))
        }
    }
}
