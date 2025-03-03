//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Combine
import DependencyInjection
import RemoteClient
import GrpcModels
@testable import OctopusCore

struct SSOExchangeTokenMonitorTests {

    /// Object that is tested
    private var ssoExchangeTokenMonitor: SSOExchangeTokenMonitor

    private let userDataStorage: UserDataStorage
    private let mockNetworkMonitor: MockNetworkMonitor
    private let mockUserService: MockUserService

    init() {
        let injector = Injector()
        injector.register { _ in try! CoreDataStack(inRam: true) }
        injector.register { UserDataStorage(injector: $0) }
        injector.registerMocks(.remoteClient, .appStateMonitor, .networkMonitor, .securedStorage)

        ssoExchangeTokenMonitor = SSOExchangeTokenMonitorDefault(injector: injector)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        mockUserService = (injector.getInjected(identifiedBy: Injected.remoteClient).userService as! MockUserService)
        mockNetworkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor) as! MockNetworkMonitor

        ssoExchangeTokenMonitor.start()
    }

    @Test func testExchangeToken() async throws {
        mockNetworkMonitor.connectionAvailable = true

        var storage = [AnyCancellable]()

        var response: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse?
        ssoExchangeTokenMonitor.getJwtFromClientTokenResponsePublisher
            .sink { response = $0 }
            .store(in: &storage)

        userDataStorage.store(clientUserData: .init(id: "userId", token: nil))
        // nothing happens, the mockUserService is not called yet
        #expect(response == nil)

        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "jwt"
                $0.userID = "userId"
            })
        })

        userDataStorage.store(clientUserData: .init(id: "userClientId", token: "token"))

        try await expectWithTimeout(response?.success.jwt == "jwt")
        try await expectWithTimeout(response?.success.userID == "userId")
    }

    @Test func testExchangeTokenWhenNetwork() async throws {
        mockNetworkMonitor.connectionAvailable = false

        var storage = [AnyCancellable]()

        var response: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse?
        ssoExchangeTokenMonitor.getJwtFromClientTokenResponsePublisher
            .sink { response = $0 }
            .store(in: &storage)

        userDataStorage.store(clientUserData: .init(id: "userId", token: "token"))
        // nothing happens, the mockUserService is not called yet
        #expect(response == nil)

        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "jwt"
                $0.userID = "userId"
            })
        })

        mockNetworkMonitor.connectionAvailable = true

        try await expectWithTimeout(response?.success.jwt == "jwt")
        try await expectWithTimeout(response?.success.userID == "userId")
    }
}
