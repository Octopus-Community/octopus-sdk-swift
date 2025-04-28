//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusDependencyInjection

extension Injected {
    static let appSessionMonitor = Injector.InjectedIdentifier<AppSessionMonitor>()
}

/// Class that monitors the app session.
/// When the app moves to background, it triggers an app session end, when the app moves to foreground, it triggers
/// an app session start.
final class AppSessionMonitor: InjectableObject {
    static let injectedIdentifier = Injected.appSessionMonitor

    private var trackingRepository: TrackingRepository
    private var appStateMonitor: AppStateMonitor
    private var storage: Set<AnyCancellable> = []

    init(injector: Injector) {
        trackingRepository = injector.getInjected(identifiedBy: Injected.trackingRepository)
        appStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor)
    }

    func start() {
        appStateMonitor.appStatePublisher
            .removeDuplicates()
            .sink { [unowned self] appState in
                switch appState {
                case .background:
                    trackingRepository.appSessionEnded()
                case .active:
                    trackingRepository.appSessionStarted()
                }
            }.store(in: &storage)
    }

    func stop() {
        trackingRepository.appSessionEnded()
        storage = []
    }
}
