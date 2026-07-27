//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

class CoreDataStackManagerTests {
    /// Non-regression test for a crash in `CoreDataStackManager.loadModel(name:)`.
    ///
    /// The static `NSManagedObjectModel` cache was read and mutated without synchronization, so test
    /// suites creating in-RAM stacks in parallel could race on the dictionary and crash the whole
    /// test runner (`Crash: xctest at static CoreDataStackManager.loadModel(name:)`).
    /// This test creates many stacks concurrently, covering the three persistent container names so
    /// that every cache entry can be hit while another one is being inserted.
    @Test func concurrentStackCreationsDoNotCrash() async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    _ = try? ModelCoreDataStack(inRam: true)
                }
                group.addTask {
                    _ = try? TrackingCoreDataStack(inRam: true)
                }
                group.addTask {
                    _ = try? ConfigCoreDataStack(inRam: true)
                }
            }
        }
    }
}
