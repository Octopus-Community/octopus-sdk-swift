//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

/// Mock of your app's edit profile view.
/// Can be embeded in the AppLoginScreen or in AppEditUserScreen.
///
/// This view lets the user edits its nickname, bio, profile picture and age information.
struct AppEditUserView: View {
    enum PictureKind {
        case empty
        case avatar1
        case avatar2

        var picture: Data? {
            return switch self {
            case .empty:    nil
            case .avatar1:  UIImage(resource: .Scenarios.SSO.avatar).jpegData(compressionQuality: 1.0)
            case .avatar2:  UIImage(resource: .Scenarios.SSO.avatar2).pngData()
            }
        }

        init(from data: Data?) {
            self = switch data {
            case PictureKind.empty.picture:     .empty
            case PictureKind.avatar1.picture:   .avatar1
            case PictureKind.avatar2.picture:   .avatar2
            default:                            .empty
            }
        }
    }
    let displayAge: Bool
    @Binding var nickname: String
    @Binding var bio: String
    @Binding var picture: Data?
    @Binding var ageInformation: AppUser.AgeInfo?

    @State private var pictureKind = PictureKind.empty

    var body: some View {
        VStack(alignment: .leading) {
            Text("Nickname:")
            TextField("Nickname", text: $nickname)
            Spacer().frame(height: 20)
            Text("Bio:")
            TextField("Bio", text: $bio)
            Spacer().frame(height: 20)
            Text("Picture")
            Picker("", selection: $pictureKind) {
                Text("None").tag(PictureKind.empty)
                Text("Avatar 1").tag(PictureKind.avatar1)
                Text("Avatar 2").tag(PictureKind.avatar2)
            }
            .pickerStyle(.segmented)
            if let picture, let image = UIImage(data: picture) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 90)
            }
            if displayAge {
                Text("Information about the age")
                Picker("", selection: $ageInformation) {
                    Text("Not checked").tag(nil as AppUser.AgeInfo?)
                    Text(">= 16").tag(AppUser.AgeInfo.moreThan16)
                    Text("< 16").tag(AppUser.AgeInfo.lessThan16)
                }
                .pickerStyle(.segmented)
            }
            Spacer()
        }
        .padding()
        .onAppear {
            pictureKind = PictureKind(from: picture)
        }
        .onValueChanged(of: pictureKind) { pictureKind in
            picture = pictureKind.picture
        }
    }
}
