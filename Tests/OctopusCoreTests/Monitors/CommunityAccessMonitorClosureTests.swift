//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusDependencyInjection
@testable import OctopusCore

/// The access monitor is stopped while the community is closed: nothing it planned may ask the access meanwhile.
@Suite(.serialized)
struct CommunityAccessMonitorClosureTests {

    @Test func aStoppedMonitorDoesNotRecheckLater() async throws {
        let injector = makeInjector()
        let userService = try #require(
            injector.getInjected(identifiedBy: Injected.remoteClient).userService as? MockUserService)
        userService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        userService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        let monitor = CommunityAccessMonitor(injector: injector)
        monitor.recheckDelay = 0.1
        monitor.start()
        try await expectWithTimeout(userService.canAccessCommunityCallCount == 1)

        monitor.stop()

        try await Task.sleep(nanoseconds: .secondsToNano(0.4))
        #expect(userService.canAccessCommunityCallCount == 1)
    }

    @Test func aRestartedMonitorAsksTheAccessAgain() async throws {
        let injector = makeInjector()
        let userService = try #require(
            injector.getInjected(identifiedBy: Injected.remoteClient).userService as? MockUserService)
        userService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        userService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        let monitor = CommunityAccessMonitor(injector: injector)
        monitor.start()
        try await expectWithTimeout(userService.canAccessCommunityCallCount == 1)

        monitor.stop()
        monitor.start()

        try await expectWithTimeout(userService.canAccessCommunityCallCount == 2)
        monitor.stop()
    }

    private func makeInjector() -> Injector {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .appStateMonitor, .authProvider,
                               .communityClosure)
        injector.register { UserDataStorage(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.getInjected(identifiedBy: Injected.userDataStorage)
            .store(userData: .init(id: "userId", jwtToken: "token"))
        return injector
    }
}
