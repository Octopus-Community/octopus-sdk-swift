//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Testing
import OctopusDependencyInjection
@testable import OctopusCore

@Suite(.serialized)
struct TrackingCtaGroupTests {

    @Test
    func eventEntityCreate_producesCtaGroupButtonHitEntity() async throws {
        let injector = Injector()
        injector.register { _ in try! TrackingCoreDataStack(inRam: true) }
        let stack = injector.getInjected(identifiedBy: Injected.trackingCoreDataStack)
        let context = stack.saveContext

        let event = Event(
            date: Date(),
            appSessionId: "app-session-1",
            uiSessionId: "ui-session-1",
            content: .ctaGroupButtonHit(groupId: "topic-7"))

        try await context.performAsync { [context] in
            EventEntity.create(from: event, context: context)
            try context.save()
        }

        let stored: [CtaGroupButtonHitEntity] = try await context.performAsync { [context] in
            let request = NSFetchRequest<CtaGroupButtonHitEntity>(entityName: "CtaGroupButtonHit")
            return try context.fetch(request)
        }

        #expect(stored.count == 1)
        #expect(stored.first?.octoObjectId == "topic-7")
    }

    @Test
    func eventInitFromEntity_reconstructsCtaGroupButtonHit() async throws {
        let injector = Injector()
        injector.register { _ in try! TrackingCoreDataStack(inRam: true) }
        let stack = injector.getInjected(identifiedBy: Injected.trackingCoreDataStack)
        let context = stack.saveContext

        let event = Event(
            date: Date(),
            appSessionId: nil,
            uiSessionId: nil,
            content: .ctaGroupButtonHit(groupId: "topic-9"))

        try await context.performAsync { [context] in
            EventEntity.create(from: event, context: context)
            try context.save()
        }

        let reconstructed: Event? = try await context.performAsync { [context] in
            let request = NSFetchRequest<EventEntity>(entityName: "Event")
            guard let entity = try context.fetch(request).first else { return nil }
            return Event(from: entity)
        }

        #expect(reconstructed != nil)
        if case let .ctaGroupButtonHit(groupId) = reconstructed?.content {
            #expect(groupId == "topic-9")
        } else {
            Issue.record("Expected .ctaGroupButtonHit content, got \(String(describing: reconstructed?.content))")
        }
    }
}
