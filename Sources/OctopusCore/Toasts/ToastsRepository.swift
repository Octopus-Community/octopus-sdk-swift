//
//  Copyright © 2025 Octopus Community. All rights reserved.
//


import Foundation
import Combine
import UserNotifications
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
import os

extension Injected {
    static let toastsRepository = Injector.InjectedIdentifier<ToastsRepository>()
}

/// A repository in charge of publishing the list of toasts to display
public class ToastsRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.toastsRepository

    @Published public private(set) var toasts: [Toast] = []

    private var gamificationConfig: GamificationConfig? = nil
    private var storage = [AnyCancellable]()

    private var gamificationToastAlreadyDisplayed = Set<GamificationAction>()

    init(injector: Injector) {
        let configRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        let appStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor)
        configRepository.communityConfigPublisher
            .map { $0?.gamificationConfig }
            .sink { [unowned self] in
                gamificationConfig = $0
            }
            .store(in: &storage)

        appStateMonitor.appStatePublisher
            .sink { [unowned self] in
                guard $0 == .background else { return }
                resetDisplayedToasts()
            }.store(in: &storage)
    }
    
    /// Resets the list of displayed toasts in order to display them again if they occur
    public func resetDisplayedToasts() {
        gamificationToastAlreadyDisplayed.removeAll()
    }

    /// Tells the repository that some toasts have been displayed
    /// - Parameter toastsToRemove: the toasts to remove from the list
    public func consummed(toasts toastsToRemove: [Toast]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !toasts.isEmpty else { return }
            // make the change only update once the published value
            var newToasts = toasts
            newToasts.removeAll(where: { toastsToRemove.contains($0) })
            toasts = newToasts
        }
    }

    func display(gamificationToast action: GamificationAction) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let config = gamificationConfig,
               let points = config.pointsByAction[action],
               !gamificationToastAlreadyDisplayed.contains(action) {
                toasts.append(.gamification(GamificationToast(
                    action: action,
                    formattedPoints: "\(points) \(points > 1 ? config.abbrevPointPlural : config.abbrevPointPlural)")))
                // since we do not want to display both reply and comment actions,
                if action == .reply || action == .comment {
                    gamificationToastAlreadyDisplayed.insert(.reply)
                    gamificationToastAlreadyDisplayed.insert(.comment)
                } else {
                    gamificationToastAlreadyDisplayed.insert(action)
                }
            }
        }
    }
}
