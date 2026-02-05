//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusDependencyInjection

extension Injected {
    static let gamificationRepository = Injector.InjectedIdentifier<GamificationRepository>()
}

class GamificationRepository: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.gamificationRepository

    private let toastsRepository: ToastsRepository
    private let sdkEventsEmitter: SdkEventsEmitter

    private var gamificationConfig: GamificationConfig? = nil
    private var storage = [AnyCancellable]()

    private var gamificationToastAlreadyDisplayed = Set<GamificationAction>()

    init(injector: Injector) {
        toastsRepository = injector.getInjected(identifiedBy: Injected.toastsRepository)
        sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)

        let configRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        configRepository.communityConfigPublisher
            .map { $0?.gamificationConfig }
            .sink { [unowned self] in
                gamificationConfig = $0
            }
            .store(in: &storage)
    }

    func register(action: GamificationAction) {
        guard let config = gamificationConfig,
              let points = config.pointsByAction[action] else { return }

        toastsRepository.display(gamificationToast: action)
        sdkEventsEmitter.emit(.gamificationPointsGained(.init(pointsGained: points, coreAction: action.sdkEventValue)))
    }

    func unregister(action: GamificationAction) {
        guard let config = gamificationConfig,
              let points = config.pointsByAction[action],
              let eventAction = action.pointsRemovedSdkEventValue else { return }

        sdkEventsEmitter.emit(.gamificationPointsRemoved(.init(pointsRemoved: points, coreAction: eventAction)))
    }
}
