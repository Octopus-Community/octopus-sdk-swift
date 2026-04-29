//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import OctopusDependencyInjection
@testable import OctopusCore

class ClientSetABTestEventTests: XCTestCase {
    private var eventsDatabase: EventsDatabase!

    override func setUp() {
        let injector = Injector()
        injector.register { _ in try! TrackingCoreDataStack(inRam: true) }
        injector.register { EventsDatabase(injector: $0) }
        eventsDatabase = injector.getInjected(identifiedBy: Injected.eventsDatabase)
    }

    // MARK: - CoreData Round-Trip

    func testClientSetABTestTrue_roundTrips() async throws {
        let event = Event(
            date: Date(),
            appSessionId: "app-session-1",
            uiSessionId: "ui-session-1",
            content: .clientSetABTest(hasAccessToCommunity: true))

        try await eventsDatabase.upsert(event: event)
        let storedEvents = try await eventsDatabase.getAllEvents()

        XCTAssertEqual(storedEvents.count, 1)
        let stored = try XCTUnwrap(storedEvents.first)
        XCTAssertEqual(stored.uuid, event.uuid)
        XCTAssertEqual(stored.appSessionId, "app-session-1")
        XCTAssertEqual(stored.uiSessionId, "ui-session-1")
        if case let .clientSetABTest(hasAccess) = stored.content {
            XCTAssertTrue(hasAccess)
        } else {
            XCTFail("Expected clientSetABTest event, got \(stored.content)")
        }
    }

    func testClientSetABTestFalse_roundTrips() async throws {
        let event = Event(
            date: Date(),
            appSessionId: nil,
            uiSessionId: nil,
            content: .clientSetABTest(hasAccessToCommunity: false))

        try await eventsDatabase.upsert(event: event)
        let storedEvents = try await eventsDatabase.getAllEvents()

        XCTAssertEqual(storedEvents.count, 1)
        let stored = try XCTUnwrap(storedEvents.first)
        if case let .clientSetABTest(hasAccess) = stored.content {
            XCTAssertFalse(hasAccess)
        } else {
            XCTFail("Expected clientSetABTest event, got \(stored.content)")
        }
    }
}
