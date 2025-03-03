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

struct MagicLinkMonitorTests {

    /// Object that is tested
    private var magicLinkMonitor: MagicLinkMonitor

    private let userDataStorage: UserDataStorage
    private let mockNetworkMonitor: MockNetworkMonitor
    private let mockAppStateMonitor: MockAppStateMonitor
    private let mockMagicLinkService: MockMagicLinkService
    private let mockMagicLinkStreamService: MockMagicLinkStreamService

    init() {
        let injector = Injector()
        injector.register { _ in try! CoreDataStack(inRam: true) }
        injector.register { UserDataStorage(injector: $0) }
        injector.register { MagicLinkConnectionRepository(connectionMode: .octopus(deepLink: nil), injector: $0) }
        injector.registerMocks(.remoteClient, .appStateMonitor, .networkMonitor, .securedStorage)

        magicLinkMonitor = MagicLinkMonitorDefault(injector: injector)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        mockMagicLinkService = (injector.getInjected(identifiedBy: Injected.remoteClient).magicLinkService as! MockMagicLinkService)
        mockMagicLinkStreamService = (injector.getInjected(identifiedBy: Injected.remoteClient).magicLinkStreamService as! MockMagicLinkStreamService)
        mockNetworkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor) as! MockNetworkMonitor
        mockAppStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor) as! MockAppStateMonitor

        magicLinkMonitor.start()
    }

    @Test func testGetJwtWhenAppGoesToForeground() async throws {
        mockAppStateMonitor.appState = .active
        mockNetworkMonitor.connectionAvailable = true

        var storage = [AnyCancellable]()

        var response: Com_Octopuscommunity_IsAuthenticatedResponse?
        magicLinkMonitor.magicLinkAuthenticationResponsePublisher
            .sink { response = $0 }
            .store(in: &storage)

        userDataStorage.store(magicLinkData: .init(magicLinkId: "id", email: "t@t.c"))
        // nothing happens, the mockMagicLinkService is not called yet
        #expect(response == nil)

        mockAppStateMonitor.appState = .background
        #expect(response == nil)

        mockMagicLinkService.injectNextGetJwtResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "abc"
                $0.userID = "userId"
            })
        })
        mockAppStateMonitor.appState = .active

        try await expectWithTimeout(response?.success.jwt == "abc")
        try await expectWithTimeout(response?.success.userID == "userId")
    }

    @Test func testGetJwtWhenAppHasConnectivityAfterGoingToForeground() async throws {
        mockAppStateMonitor.appState = .active
        mockNetworkMonitor.connectionAvailable = false

        var storage = [AnyCancellable]()

        var response: Com_Octopuscommunity_IsAuthenticatedResponse?
        magicLinkMonitor.magicLinkAuthenticationResponsePublisher
            .sink { response = $0 }
            .store(in: &storage)

        userDataStorage.store(magicLinkData: .init(magicLinkId: "id", email: "t@t.c"))
        // nothing happens, the mockMagicLinkService is not called yet
        #expect(response == nil)

        mockAppStateMonitor.appState = .background
        #expect(response == nil)

        mockMagicLinkService.injectNextGetJwtResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "abc"
                $0.userID = "userId"
            })
        })
        mockAppStateMonitor.appState = .active
        try await delay()
        #expect(response == nil)

        mockNetworkMonitor.connectionAvailable = true

        try await expectWithTimeout(response?.success.jwt == "abc")
        try await expectWithTimeout(response?.success.userID == "userId")
    }

    @Test func testSubscribeIsChangingUserState() async throws {
        mockNetworkMonitor.connectionAvailable = true

        var storage = [AnyCancellable]()

        var response: Com_Octopuscommunity_IsAuthenticatedResponse?
        magicLinkMonitor.magicLinkAuthenticationResponsePublisher
            .sink { response = $0 }
            .store(in: &storage)

        userDataStorage.store(magicLinkData: .init(magicLinkId: "id", email: "t@t.c"))
        // the subscription should be opened

        try mockMagicLinkStreamService.streamSubscribeResponse(.with {
            $0.error = .with {
                $0.errorCode = .notAuthenticatedYet
            }
        })

        try await expectWithTimeout(response?.error.errorCode == .notAuthenticatedYet)

        try mockMagicLinkStreamService.streamSubscribeResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "abc"
                $0.userID = "userId"
            })
        })

        try await expectWithTimeout(response?.success.jwt == "abc")
        try await expectWithTimeout(response?.success.userID == "userId")
    }
}
