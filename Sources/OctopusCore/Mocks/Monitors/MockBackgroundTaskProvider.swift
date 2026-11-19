//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection

final class MockBackgroundTaskProvider: BackgroundTaskProvider, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.backgroundTaskProvider

    private let lock = NSLock()
    private var tasks: [(task: BackgroundTask, expirationHandler: @Sendable () -> Void)] = []

    /// The tasks that have begun and are not ended yet
    var runningTasks: [BackgroundTask] {
        lock.lock()
        defer { lock.unlock() }
        return tasks.map(\.task)
    }

    func beginTask(expirationHandler: @escaping @Sendable () -> Void) -> BackgroundTask {
        let task = BackgroundTask()
        lock.lock()
        tasks.append((task, expirationHandler))
        lock.unlock()
        return task
    }

    func endTask(_ task: BackgroundTask) {
        lock.lock()
        tasks.removeAll { $0.task === task }
        lock.unlock()
    }

    /// Simulates the system running out of background time: calls the expiration handlers, then ends the tasks.
    func expireRunningTasks() {
        lock.lock()
        let expiringTasks = tasks
        lock.unlock()
        for (task, expirationHandler) in expiringTasks {
            expirationHandler()
            endTask(task)
        }
    }
}
