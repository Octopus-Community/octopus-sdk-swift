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

    static let signedOutKey = "OctopusSample.account.signedOut"

    private let userDefaults: UserDefaults

    /// Whether the user signed out of the community while staying the app's user: a Disconnect keeps the record,
    /// so Connect can sign the same user back in, but the app must not sign them in again on its next launch.
    /// Read from the defaults on every access, so the manager's tasks never race on a copy.
    var isSignedOut: Bool { userDefaults.bool(forKey: Self.signedOutKey) }

    init(defaults: UserDefaults = .standard) {
        userDefaults = defaults
        // load the stored value
        guard let id = userDefaults.string(forKey: idKey) else { return }
        let nickname = userDefaults.string(forKey: nicknameKey)
        let bio = userDefaults.string(forKey: bioKey)
        let picture = userDefaults.data(forKey: pictureKey)
        user = .init(userId: id, nickname: nickname, bio: bio, picture: picture)
    }

    /// Stores the app's user. Storing one, even the same, is a sign-in: it clears `isSignedOut` before `user`
    /// publishes, so its subscribers already read the new state.
    func set(user: AppUser?) {
        userDefaults.set(user?.userId, forKey: idKey)
        userDefaults.set(user?.nickname, forKey: nicknameKey)
        userDefaults.set(user?.bio, forKey: bioKey)
        userDefaults.set(user?.picture, forKey: pictureKey)
        setSignedOut(false)
        self.user = user
    }

    func setSignedOut(_ signedOut: Bool) {
        userDefaults.set(signedOut, forKey: Self.signedOutKey)
    }
}
