//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Combine
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
@testable import OctopusCore

struct CommunityAccessMonitorTests {

    /// Object that is tested
    private let communityAccessMonitor: CommunityAccessMonitor

    private let userDataStorage: UserDataStorage
    private let userConfigDatabase: UserConfigDatabase
    private let mockNetworkMonitor: MockNetworkMonitor
    private let mockAppStateMonitor: MockAppStateMonitor
    private let mockUserService: MockUserService
    private let mockRemoteClient: MockRemoteClient

    /// Long enough for a retry that should not happen to show up: the quick retries take 0.1 s in all.
    private let noRetryWait: TimeInterval = 0.5

    init() {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.register { UserDataStorage(injector: $0) }
        injector.registerMocks(.remoteClient, .appStateMonitor, .networkMonitor, .securedStorage, .authProvider,
                               .communityClosure)

        communityAccessMonitor = CommunityAccessMonitor(injector: injector, quickRetryDelays: [0.05, 0.05])
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
        mockNetworkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor) as! MockNetworkMonitor
        mockAppStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor) as! MockAppStateMonitor
        mockRemoteClient = injector.getInjected(identifiedBy: Injected.remoteClient) as! MockRemoteClient
        mockUserService = mockRemoteClient.userService as! MockUserService

        communityAccessMonitor.start()
    }

    @Test func testFetchesTheAccessOnceTheUserIsKnown() async throws {
        var storage = [AnyCancellable]()
        let userConfig = Locked<UserConfig?>(nil)
        userConfigDatabase.configPublisher()
            .sink { userConfig.value = $0 }
            .store(in: &storage)

        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = false })
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))

        try await expectWithTimeout(userConfig.value?.canAccessCommunity == false)
        #expect(mockUserService.canAccessCommunityCallCount == 1)
    }

    @Test func testStoresTheReasonTheServerGives() async throws {
        var storage = [AnyCancellable]()
        var userConfig: UserConfig?
        userConfigDatabase.configPublisher()
            .sink { userConfig = $0 }
            .store(in: &storage)

        mockUserService.injectNextCanAccessCommunityResponse(.with {
            $0.canAccessCommunity = false
            $0.memberExcluded = .init()
        })
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))

        try await expectWithTimeout(userConfig?.noAccessReason == .memberExcluded)
    }

    @Test func testRecoversFromAPassingFailureWithAQuickRetry() async throws {
        var storage = [AnyCancellable]()
        let userConfig = Locked<UserConfig?>(nil)
        userConfigDatabase.configPublisher()
            .sink { userConfig.value = $0 }
            .store(in: &storage)

        mockUserService.injectNextCanAccessCommunityError(.timeout)
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))

        try await expectWithTimeout(userConfig.value?.canAccessCommunity == true)
        #expect(mockUserService.canAccessCommunityCallCount == 2)
    }

    @Test func testStopsRetryingWhileTheAppStaysActive() async throws {
        failThreeTimes()
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 3)

        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockUserService.canAccessCommunityCallCount == 3)
    }

    @Test func testFetchesAgainWhenTheAppComesBackAfterTheRetriesFailed() async throws {
        var storage = [AnyCancellable]()
        let userConfig = Locked<UserConfig?>(nil)
        userConfigDatabase.configPublisher()
            .sink { userConfig.value = $0 }
            .store(in: &storage)

        failThreeTimes()
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 3)
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))

        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = false })
        mockAppStateMonitor.appState = .background
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockUserService.canAccessCommunityCallCount == 3)

        mockAppStateMonitor.appState = .active
        try await expectWithTimeout(userConfig.value?.canAccessCommunity == false)
        #expect(mockUserService.canAccessCommunityCallCount == 4)
    }

    @Test func testFetchesAgainWhenTheNetworkComesBackAfterTheRetriesFailed() async throws {
        failThreeTimes()
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 3)
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))

        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        mockNetworkMonitor.connectionAvailable = false
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockUserService.canAccessCommunityCallCount == 3)

        mockNetworkMonitor.connectionAvailable = true
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 4)
    }

    @Test func testAnErrorTheServerKeepsReturningIsAskedAgainOnlyWhenTheAppComesBack() async throws {
        failThreeTimes()
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 3)
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))

        failThreeTimes()
        mockAppStateMonitor.appState = .background
        mockAppStateMonitor.appState = .active
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 6)

        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockUserService.canAccessCommunityCallCount == 6)
    }

    @Test func testStopDisarmsTheRetry() async throws {
        failThreeTimes()
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 3)
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))

        communityAccessMonitor.stop()
        mockAppStateMonitor.appState = .background
        mockAppStateMonitor.appState = .active
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockUserService.canAccessCommunityCallCount == 3)
    }

    @Test func testFetchesOnlyOnceWhenTheAppComesBackAfterASuccess() async throws {
        var storage = [AnyCancellable]()
        let userConfig = Locked<UserConfig?>(nil)
        userConfigDatabase.configPublisher()
            .sink { userConfig.value = $0 }
            .store(in: &storage)

        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(userConfig.value?.canAccessCommunity == true)

        mockAppStateMonitor.appState = .background
        mockAppStateMonitor.appState = .active
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockUserService.canAccessCommunityCallCount == 1)
    }

    // MARK: An access taken away while the app runs

    /// A ban or an exclusion decided while the app runs first shows as calls the server refuses: the access says
    /// why, without waiting for the next launch.
    @Test func testReadsTheAccessAgainWhenACallIsRefused() async throws {
        var storage = [AnyCancellable]()
        var userConfig: UserConfig?
        userConfigDatabase.configPublisher()
            .sink { userConfig = $0 }
            .store(in: &storage)
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(userConfig?.canAccessCommunity == true)

        mockUserService.injectNextCanAccessCommunityResponse(.with {
            $0.canAccessCommunity = false
            $0.memberExcluded = .init()
        })
        mockRemoteClient.accessRefusedHandler?(false)

        try await expectWithTimeout(userConfig?.noAccessReason == .memberExcluded)
        #expect(mockUserService.canAccessCommunityCallCount == 2)
    }

    /// The calls of a screen are all refused at once, and a hidden group is refused the same way: one read answers
    /// them all.
    @Test func testReadsTheAccessOnceForRefusalsInARow() async throws {
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 1)

        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        mockRemoteClient.accessRefusedHandler?(false)
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 2)
        mockRemoteClient.accessRefusedHandler?(false)
        mockRemoteClient.accessRefusedHandler?(false)

        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockUserService.canAccessCommunityCallCount == 2)
    }

    @Test func testReadsTheAccessAgainForARefusalOnceTheIntervalHasPassed() async throws {
        communityAccessMonitor.minIntervalBetweenRefusalReads = 0.1
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 1)
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        mockRemoteClient.accessRefusedHandler?(false)
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 2)

        try await Task.sleep(nanoseconds: .secondsToNano(0.2))
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        mockRemoteClient.accessRefusedHandler?(false)

        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 3)
    }

    /// The calls of a member without access keep being refused (tracking, notifications): the access is known,
    /// and the access denied screen reads it again by itself.
    @Test func testDoesNotReadAnAccessAlreadyDeniedWhenACallIsRefused() async throws {
        var storage = [AnyCancellable]()
        var userConfig: UserConfig?
        userConfigDatabase.configPublisher()
            .sink { userConfig = $0 }
            .store(in: &storage)
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = false })
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(userConfig?.canAccessCommunity == false)
        // Lets the monitor receive the stored access
        try await Task.sleep(nanoseconds: .secondsToNano(0.1))

        mockRemoteClient.accessRefusedHandler?(false)

        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockUserService.canAccessCommunityCallCount == 1)
    }

    /// The guest a banned device was given keeps being refused while the ban lasts, so the stored access is a refusal.
    /// Once the ban is lifted, the server ends that session: the stored ban does not know it, the access is read.
    @Test func testReadsAnAccessAlreadyDeniedWhenACallIsRefusedBecauseTheSessionIsOver() async throws {
        var storage = [AnyCancellable]()
        var userConfig: UserConfig?
        userConfigDatabase.configPublisher()
            .sink { userConfig = $0 }
            .store(in: &storage)
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = false })
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(userConfig?.canAccessCommunity == false)
        // Lets the monitor receive the stored access
        try await Task.sleep(nanoseconds: .secondsToNano(0.1))
        mockUserService.injectNextCanAccessCommunityResponse(.with {
            $0.canAccessCommunity = false
            $0.sessionEnded = .init()
        })
        var endedSession: UserDataStorage.UserData?
        userConfigDatabase.endedSessionPublisher
            .sink { endedSession = $0 }
            .store(in: &storage)

        mockRemoteClient.accessRefusedHandler?(true)

        // Reported to be replaced, not stored as the access
        try await expectWithTimeout(endedSession?.id == "userId")
        #expect(mockUserService.canAccessCommunityCallCount == 2)
        #expect(userConfig?.noAccessReason == .unknown)
    }

    /// Stopped while the community is closed: a refusal must not ask the access then.
    @Test func testAStoppedMonitorDoesNotReadTheAccessWhenACallIsRefused() async throws {
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await expectWithTimeout(mockUserService.canAccessCommunityCallCount == 1)

        communityAccessMonitor.stop()
        mockRemoteClient.accessRefusedHandler?(false)

        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockUserService.canAccessCommunityCallCount == 1)
    }

    @Test func testDoesNotReadTheAccessForARefusalWithoutUser() async throws {
        mockRemoteClient.accessRefusedHandler?(false)

        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockUserService.canAccessCommunityCallCount == 0)
    }

    /// Makes the call and its two quick retries fail, as an error the server keeps returning does.
    private func failThreeTimes() {
        for _ in 0..<3 {
            mockUserService.injectNextCanAccessCommunityError(.permissionDenied(reason: nil))
        }
    }
}
