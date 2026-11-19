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

        let response = Locked<(Com_Octopuscommunity_GetPrivateProfileResponse, String)?>(nil)
        userProfileFetchMonitor.responses
            .sink { response.value = $0 }
            .store(in: &storage)

        mockUserService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with {
                $0.id = "userId"
                $0.nickname = "nick"
            }
        })

        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))

        try await expectWithTimeout(response.value?.0.profile.id == "userId")
        try await expectWithTimeout(response.value?.0.profile.nickname == "nick")
        try await expectWithTimeout(response.value?.1 == "userId")
    }

    /// `@Published` publishes a session before it writes it, and the fetch that session triggers runs on its own: it
    /// can be answered while the previous session is still the one written. Here a subscriber holds the write back
    /// until the response is in, which used to drop that response as one for a session that had changed meanwhile.
    ///
    /// `@Published` calls its subscribers in no set order. When the one holding the write is called before the
    /// monitor, no fetch is running yet and nothing is held: the test then connects another user, with a new
    /// subscription that takes another place, until the write of one is held. Should none of them be, which is unlikely,
    /// the test passes without having checked anything.
    @Test func testFetchProfileAnsweredBeforeTheSessionIsWritten() async throws {
        var storage = [AnyCancellable]()

        let response = Locked<(Com_Octopuscommunity_GetPrivateProfileResponse, String)?>(nil)
        userProfileFetchMonitor.responses
            .sink { response.value = $0 }
            .store(in: &storage)

        for attempt in 1...10 {
            let userId = "userId\(attempt)"
            let writeWasHeld = Locked(false)
            // kept until the end: cancelled, the next subscription could reuse its memory, and its place
            userDataStorage.$userData
                .sink {
                    guard $0?.id == userId else { return }
                    let deadline = Date().addingTimeInterval(1)
                    while response.value?.1 != userId && Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.005)
                    }
                    writeWasHeld.value = response.value?.1 == userId
                }
                .store(in: &storage)
            mockUserService.injectNextGetPrivateProfileResponse(.with {
                $0.profile = .with { $0.id = userId }
            })

            // off the test's thread, which the held write would block
            let isStored = Locked(false)
            DispatchQueue.global().async { [userDataStorage] in
                userDataStorage.store(userData: .init(id: userId, jwtToken: "userToken"))
                isStored.value = true
            }

            try await expectWithTimeout(response.value?.1 == userId)
            try await expectWithTimeout(isStored.value)
            guard response.value?.1 == userId, !writeWasHeld.value else { return }
        }
    }

    /// The session can change while its profile is being fetched: that profile is not the new user's, and is dropped.
    @Test func testFetchProfileAnsweredAfterTheSessionChangedIsDropped() async throws {
        var storage = [AnyCancellable]()

        let responseUserIds = Locked<[String]>([])
        userProfileFetchMonitor.responses
            .sink { response in responseUserIds.mutate { $0.append(response.1) } }
            .store(in: &storage)

        mockUserService.getPrivateProfileLatency = .secondsToNano(0.3)
        mockUserService.injectNextGetPrivateProfileResponse(.with { $0.profile = .with { $0.id = "previousUserId" } })
        mockUserService.injectNextGetPrivateProfileResponse(.with { $0.profile = .with { $0.id = "userId" } })

        userDataStorage.store(userData: .init(id: "previousUserId", jwtToken: "previousToken"))
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))

        try await expectWithTimeout(responseUserIds.value == ["userId"])
        // leave the time for the response of the previous session to show up, would it
        try await Task.sleep(nanoseconds: .secondsToNano(0.3))
        #expect(responseUserIds.value == ["userId"])
    }

    @Test func testFetchProfileWhenAllRequirementsAreNotYetMet() async throws {
        mockAppStateMonitor.appState = .background
        mockNetworkMonitor.connectionAvailable = false
        userProfileFetchMonitor.set(connectionInProgress: true)

        var storage = [AnyCancellable]()

        let response = Locked<(Com_Octopuscommunity_GetPrivateProfileResponse, String)?>(nil)
        userProfileFetchMonitor.responses
            .sink { response.value = $0 }
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

        try await expectWithTimeout(response.value?.0.profile.id == "userId")
        try await expectWithTimeout(response.value?.0.profile.nickname == "nick")
        try await expectWithTimeout(response.value?.1 == "userId")
    }

    @Test func testFetchProfileIsNotDoneTwiceWhenRequirementsChange() async throws {
        mockAppStateMonitor.appState = .background
        mockNetworkMonitor.connectionAvailable = false
        userProfileFetchMonitor.set(connectionInProgress: true)

        var storage = [AnyCancellable]()

        let response = Locked<(Com_Octopuscommunity_GetPrivateProfileResponse, String)?>(nil)
        userProfileFetchMonitor.responses
            .sink { response.value = $0 }
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

        try await expectWithTimeout(response.value?.0.profile.id == "userId")
        try await expectWithTimeout(response.value?.0.profile.nickname == "nick")
        try await expectWithTimeout(response.value?.1 == "userId")

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

        let response = Locked<(Com_Octopuscommunity_GetPrivateProfileResponse, String)?>(nil)
        userProfileFetchMonitor.responses
            .sink { response.value = $0 }
            .store(in: &storage)

        // the request will be triggered as soon as the last requirement is met
        mockUserService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with {
                $0.id = "userId2"
                $0.nickname = "bob"
            }
        })

        userDataStorage.store(userData: .init(id: "userId2", jwtToken: "userToken"))

        try await expectWithTimeout(response.value?.0.profile.id == "userId2")
        try await expectWithTimeout(response.value?.0.profile.nickname == "bob")
        try await expectWithTimeout(response.value?.1 == "userId2")
    }

    /// The ticket of a response is taken when its request is sent, not when its answer arrives: a write made while the
    /// request was in flight read a newer state, and must win over it (see `ProfileGamificationOrder`).
    @Test func testResponseCarriesTheTicketTakenWhenItsRequestWasSent() async throws {
        mockAppStateMonitor.appState = .active
        mockNetworkMonitor.connectionAvailable = true
        userProfileFetchMonitor.set(connectionInProgress: false)

        var storage = [AnyCancellable]()
        let ticket = Locked<ProfileGamificationOrder.Ticket?>(nil)
        userProfileFetchMonitor.orderedUserProfileResponsePublisher
            .sink { ticket.value = $0.2 }
            .store(in: &storage)
        let hold = ResponseHold()
        mockUserService.getPrivateProfileHold = { await hold.pass() }
        mockUserService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with { $0.id = "userId" }
        })

        let beforeTheRequest = ProfileGamificationOrder.nextTicket()
        userDataStorage.store(userData: .init(id: "userId", jwtToken: "userToken"))
        try await hold.waitUntilReached()
        let whileTheAnswerIsHeld = ProfileGamificationOrder.nextTicket()
        await hold.release()

        try await expectWithTimeout(ticket.value != nil)
        let emittedTicket = try #require(ticket.value)
        #expect(emittedTicket > beforeTheRequest)
        #expect(emittedTicket < whileTheAnswerIsHeld)
    }
}

private extension UserProfileFetchMonitor {
    /// The responses without their tickets, which only the test above looks at.
    var responses: AnyPublisher<(Com_Octopuscommunity_GetPrivateProfileResponse, String), Never> {
        orderedUserProfileResponsePublisher
            .map { response, userId, _ in (response, userId) }
            .eraseToAnyPublisher()
    }
}
