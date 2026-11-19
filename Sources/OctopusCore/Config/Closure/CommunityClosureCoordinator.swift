//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine

/// Runs the monitors that call the server only while the community is open.
///
/// Their calls would be blocked anyway while it is closed, but stopping them keeps them from retrying for nothing,
/// and starting them again on reopening makes them fetch what they fetch at launch (access, profile...).
final class CommunityClosureCoordinator {
    private let closurePublisher: AnyPublisher<CommunityClosure?, Never>
    private let isClosed: () -> Bool
    private let startServerMonitors: () -> Void
    private let stopServerMonitors: () -> Void
    private let resume: () -> Void

    private var cancellable: AnyCancellable?

    /// - Parameters:
    ///   - resume: loads what a launch loads besides the monitors, once the community reopened.
    init(closurePublisher: AnyPublisher<CommunityClosure?, Never>, isClosed: @escaping () -> Bool,
         startServerMonitors: @escaping () -> Void, stopServerMonitors: @escaping () -> Void,
         resume: @escaping () -> Void) {
        self.closurePublisher = closurePublisher
        self.isClosed = isClosed
        self.startServerMonitors = startServerMonitors
        self.stopServerMonitors = stopServerMonitors
        self.resume = resume
    }

    func start() {
        if !isClosed() {
            startServerMonitors()
        }
        // The closure changes from the task that received the config: the monitors are started and stopped on the
        // main queue, as at launch.
        cancellable = closurePublisher
            .map { $0 != nil }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [startServerMonitors, stopServerMonitors, resume] closed in
                if closed {
                    stopServerMonitors()
                } else {
                    startServerMonitors()
                    resume()
                }
            }
    }

    func stop() {
        cancellable = nil
    }
}
