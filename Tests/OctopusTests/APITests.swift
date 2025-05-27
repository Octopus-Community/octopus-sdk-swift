//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Octopus

@Suite(.disabled("Disabled because we only need that they compile"))
class APITests {
    @Test func testOctopusSDKApi() async throws {
        _ = try OctopusSDK(apiKey: "API_KEY")
    }

    @Test func testConnectionModeSSOWithAssociatedFields() throws {
        let ssoConfiguration = ConnectionMode.SSOConfiguration(
            appManagedFields: Set(ConnectionMode.SSOConfiguration.ProfileField.allCases),
            loginRequired: { },
            modifyUser: { profile in
                switch profile {
                case .nickname, .bio, .picture: break
                case .none: break
                }
            }
        )
        _ = try OctopusSDK(apiKey: "API_KEY", connectionMode: .sso(ssoConfiguration))
    }

    @Test func testConnectionModeSSOWithoutAssociatedFields() throws {
        let ssoConfiguration = ConnectionMode.SSOConfiguration(
            loginRequired: { }
        )
        _ = try OctopusSDK(apiKey: "API_KEY", connectionMode: .sso(ssoConfiguration))
    }

    @Test func testConnectionModeOctopus() throws {
        _ = try OctopusSDK(apiKey: "API_KEY", connectionMode: .octopus(deepLink: "DEEP_LINK"))
    }

    @Test func testConnectUser() async throws {
        let ssoConfiguration = ConnectionMode.SSOConfiguration(loginRequired: { })
        let octopus = try OctopusSDK(apiKey: "API_KEY", connectionMode: .sso(ssoConfiguration))

        octopus.connectUser(
            ClientUser(userId: "USER_ID", profile: .init(nickname: "NICKNAME")),
            tokenProvider: {
                try await Task.sleep(nanoseconds: 1)
                return "TOKEN"
            })
    }

    @Test func testDisconnectUser() async throws {
        let ssoConfiguration = ConnectionMode.SSOConfiguration(loginRequired: { })
        let octopus = try OctopusSDK(apiKey: "API_KEY", connectionMode: .sso(ssoConfiguration))

        octopus.disconnectUser()
    }

    @Test func testNotSeenNotificationCount() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        _ = octopus.notSeenNotificationsCount
        _ = octopus.$notSeenNotificationsCount
        try await octopus.updateNotSeenNotificationsCount()
    }

    @Test func testClientUserProfileInit() async throws {
        _ = ClientUser.Profile()
        _ = ClientUser.Profile(nickname: "")
        _ = ClientUser.Profile(nickname: "", bio: "")
        _ = ClientUser.Profile(nickname: "", bio: "", picture: nil)
        _ = ClientUser.Profile(nickname: "", bio: "", picture: nil, ageInformation: .legalAgeReached)
        _ = ClientUser.Profile(ageInformation: .underaged)
    }
}
