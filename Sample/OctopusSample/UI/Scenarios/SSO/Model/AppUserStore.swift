//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// User store
/// Only used to keep the logged in app user accross app restart. You probably do not need this class as you already
/// have your own way to store your users.
class AppUserStore {
    @Published var user: AppUser?

    private let idKey: String
    private let nicknameKey: String
    private let bioKey: String
    private let pictureKey: String
    private let ageInfoKey: String

    private let userDefaults = UserDefaults.standard

    init(prefix: String) {
        idKey = "\(prefix)_app_user_id"
        nicknameKey = "\(prefix)_app_user_nickname"
        bioKey = "\(prefix)_app_user_bio"
        pictureKey = "\(prefix)_app_user_picture"
        ageInfoKey = "\(prefix)_app_user_ageInfo"


        // load the stored value
        guard let id = userDefaults.string(forKey: idKey) else { return }
        let nickname = userDefaults.string(forKey: nicknameKey)
        let bio = userDefaults.string(forKey: bioKey)
        let picture = userDefaults.data(forKey: pictureKey)
        let ageInfo: AppUser.AgeInfo? = switch userDefaults.integer(forKey: ageInfoKey) {
        case 1: .moreThan16
        case 2: .lessThan16
        default: nil
        }
        user = .init(userId: id, nickname: nickname, bio: bio, picture: picture, ageInformation: ageInfo)
    }

    func set(user: AppUser?) {
        userDefaults.set(user?.userId, forKey: idKey)
        userDefaults.set(user?.nickname, forKey: nicknameKey)
        userDefaults.set(user?.bio, forKey: bioKey)
        userDefaults.set(user?.picture, forKey: pictureKey)
        switch user?.ageInformation {
        case .moreThan16: userDefaults.set(1, forKey: ageInfoKey)
        case .lessThan16: userDefaults.set(2, forKey: ageInfoKey)
        default:
            userDefaults.removeObject(forKey: ageInfoKey)
        }
        self.user = user
    }
}
