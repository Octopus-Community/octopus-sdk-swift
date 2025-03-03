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
    @Binding var appUser: AppUser?
    let displayAge: Bool

    @State private var nickname: String = ""
    @State private var bio: String = ""
    @State private var picture: Data?
    @State private var ageInformation: AppUser.AgeInfo?

    var body: some View {
        NavigationView {
            VStack {
                Text("Email: \(appUser?.userId ?? "")")
                AppEditUserView(displayAge: displayAge,
                             nickname: $nickname, bio: $bio, picture: $picture, ageInformation: $ageInformation)
            }
            .navigationBarTitle("Edit your profile")
            .navigationBarItems(
                leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                },
                trailing:
                    Button(action: {
                        appUser = .init(userId: appUser?.userId ?? "", nickname: nickname, bio: bio, picture: picture, ageInformation: ageInformation)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "checkmark")
                    }
            )
            .onAppear {
                nickname = appUser?.nickname ?? ""
                bio = appUser?.bio ?? ""
                picture = appUser?.picture
            }
        }
    }
}
