//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection
import UIKit

extension Injected {
    static let backgroundTaskProvider = Injector.InjectedIdentifier<BackgroundTaskProvider>()
}

/// A task that keeps the app running in the background until it is ended.
final class BackgroundTask: @unchecked Sendable {
    /// Only accessed from the main queue.
    fileprivate var identifier = UIBackgroundTaskIdentifier.invalid

    init() { }
}

/// Asks the system for time to finish some work once the app is in the background.
///
/// This is the finite-length background execution every app has: it does not need any background mode in the
/// host app's capabilities. The system grants about thirty seconds.
protocol BackgroundTaskProvider: Sendable {
    /// Begins a task that keeps the app running in the background until `endTask` is called with it.
    /// - Parameter expirationHandler: called if the system runs out of background time before the task is ended.
    ///     The task is ended right after it returns.
    func beginTask(expirationHandler: @escaping @Sendable () -> Void) -> BackgroundTask
    /// Ends a task. Ending a task twice does nothing.
    func endTask(_ task: BackgroundTask)
}

final class BackgroundTaskProviderDefault: BackgroundTaskProvider, InjectableObject {
    static let injectedIdentifier = Injected.backgroundTaskProvider

    init() { }

    /// `UIApplication.shared` is only reachable from the main thread, so the task begins and ends on the main
    /// queue, in the order these functions are called.
    func beginTask(expirationHandler: @escaping @Sendable () -> Void) -> BackgroundTask {
        let task = BackgroundTask()
        DispatchQueue.main.async {
            task.identifier = UIApplication.shared.beginBackgroundTask(withName: "Octopus.appSession") {
                expirationHandler()
                Self.end(task)
            }
        }
        return task
    }

    func endTask(_ task: BackgroundTask) {
        DispatchQueue.main.async {
            Self.end(task)
        }
    }

    @MainActor
    private static func end(_ task: BackgroundTask) {
        guard task.identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(task.identifier)
        task.identifier = .invalid
    }
}
