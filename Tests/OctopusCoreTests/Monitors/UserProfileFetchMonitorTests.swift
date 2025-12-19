//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Combine
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
@testable import OctopusCore

struct UserProfileFetchMonitorTests {

    /// Object that is tested
    private var userProfileFetchMonitor: UserProfileFetchMonitor

    private let userDataStorage: UserDataStorage
    private let mockNetworkMonitor: MockNetworkMonitor
    private let mockAppStateMonitor: MockAppStateMonitor
    private let mockUserService: MockUserService

    init() {
        let injector = Injector()
        injector.register { UserDataStorage(injector: $0) }
        injector.registerMocks(.remoteClient, .appStateMonitor, .networkMonitor, .securedStorage, .authProvider)

        userProfileFetchMonitor = UserProfileFetchMonitorDefault(injector: injector)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        mockNetworkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor) as! MockNetworkMonitor
        mockAppStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor) as! MockAppStateMonitor
        mockUserService = (injector.getInjected(identifiedBy: Injected.remoteClient).userService as! MockUserService)

        userProfileFetchMonitor.start()
    }

    @Test func testFetchProfileWhenAllRequirementsAreMet() async throws {
        mockAppStateMonitor.appState = .active
        mockNetworkMonitor.connectionAvailable = true
        userProfileFetchMonitor.set(connectionInProgress: false)

        var storage = [AnyCancellable]()

        var response: (Com_Octopuscommunity_GetPrivateProfileResponse, String)?
        userProfileFetchMonitor.userProfileResponsePublisher
            .sink { response = $0 }
            .store(in: &storage)

        mockUserService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with {
                $0.id = "userId"
                $0.nickname = "nick"
            }
        })

        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))

        try await expectWithTimeout(response?.0.profile.id == "userId")
        try await expectWithTimeout(response?.0.profile.nickname == "nick")
        try await expectWithTimeout(response?.1 == "userId")
    }

    @Test func testFetchProfileWhenAllRequirementsAreNotYetMet() async throws {
        mockAppStateMonitor.appState = .background
        mockNetworkMonitor.connectionAvailable = false
        userProfileFetchMonitor.set(connectionInProgress: true)

        var storage = [AnyCancellable]()

        var response: (Com_Octopuscommunity_GetPrivateProfileResponse, String)?
        userProfileFetchMonitor.userProfileResponsePublisher
            .sink { response = $0 }
            .store(in: &storage)

        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))

        mockAppStateMonitor.appState = .active
        mockNetworkMonitor.connectionAvailable = true

        // the request will be triggered as soon as the last requirement is met
        mockUserService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with {
                $0.id = "userId"
                $0.nickname = "nick"
            }
        })

        userProfileFetchMonitor.set(connectionInProgress: false)

        try await expectWithTimeout(response?.0.profile.id == "userId")
        try await expectWithTimeout(response?.0.profile.nickname == "nick")
        try await expectWithTimeout(response?.1 == "userId")
    }

    @Test func testFetchProfileIsNotDoneTwiceWhenRequirementsChange() async throws {
        mockAppStateMonitor.appState = .background
        mockNetworkMonitor.connectionAvailable = false
        userProfileFetchMonitor.set(connectionInProgress: true)

        var storage = [AnyCancellable]()

        var response: (Com_Octopuscommunity_GetPrivateProfileResponse, String)?
        userProfileFetchMonitor.userProfileResponsePublisher
            .sink { response = $0 }
            .store(in: &storage)

        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))

        mockAppStateMonitor.appState = .active
        mockNetworkMonitor.connectionAvailable = true

        // the request will be triggered as soon as the last requirement is met
        mockUserService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with {
                $0.id = "userId"
                $0.nickname = "nick"
            }
        })

        userProfileFetchMonitor.set(connectionInProgress: false)

        try await expectWithTimeout(response?.0.profile.id == "userId")
        try await expectWithTimeout(response?.0.profile.nickname == "nick")
        try await expectWithTimeout(response?.1 == "userId")

        // deactivating a requirement and activating it again should not trigger a new call
        mockAppStateMonitor.appState = .background
        mockAppStateMonitor.appState = .active

        mockNetworkMonitor.connectionAvailable = false
        userProfileFetchMonitor.set(connectionInProgress: true)

        mockNetworkMonitor.connectionAvailable = true
        userProfileFetchMonitor.set(connectionInProgress: false)
    }

    @Test func testFetchProfileIsNotDoneTwiceWhenJwtChanges() async throws {
        try await testFetchProfileWhenAllRequirementsAreMet()

        // setting with the same user should not trigger a new call
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken2"))
    }

    @Test func testFetchProfileDoneAgainWhenUserChanges() async throws {
        var storage = [AnyCancellable]()

        try await testFetchProfileWhenAllRequirementsAreMet()

        var response: (Com_Octopuscommunity_GetPrivateProfileResponse, String)?
        userProfileFetchMonitor.userProfileResponsePublisher
            .sink { response = $0 }
            .store(in: &storage)

        // the request will be triggered as soon as the last requirement is met
        mockUserService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with {
                $0.id = "userId2"
                $0.nickname = "bob"
            }
        })

        userDataStorage.store(userData: .init(id: "userId2", jwtToken: "userToken"))

        try await expectWithTimeout(response?.0.profile.id == "userId2")
        try await expectWithTimeout(response?.0.profile.nickname == "bob")
        try await expectWithTimeout(response?.1 == "userId2")
    }
}
