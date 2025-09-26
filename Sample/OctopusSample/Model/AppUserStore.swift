//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// User store
/// Only used to keep the logged in app user accross app restart. You probably do not need this class as you already
/// have your own way to store your users.
class AppUserStore {
    @Published var user: AppUser?

    private let idKey = "app_user_id"
    private let nicknameKey = "app_user_nickname"
    private let bioKey = "app_user_bio"
    private let pictureKey = "app_user_picture"

    private let userDefaults = UserDefaults.standard

    init() {
        // load the stored value
        guard let id = userDefaults.string(forKey: idKey) else { return }
        let nickname = userDefaults.string(forKey: nicknameKey)
        let bio = userDefaults.string(forKey: bioKey)
        let picture = userDefaults.data(forKey: pictureKey)
        user = .init(userId: id, nickname: nickname, bio: bio, picture: picture)
    }

    func set(user: AppUser?) {
        userDefaults.set(user?.userId, forKey: idKey)
        userDefaults.set(user?.nickname, forKey: nicknameKey)
        userDefaults.set(user?.bio, forKey: bioKey)
        userDefaults.set(user?.picture, forKey: pictureKey)
        self.user = user
    }
}
