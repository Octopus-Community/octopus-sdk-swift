//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore

@MainActor
final class ToastContainerViewModel: ObservableObject {
    @Published var toasts: [DisplayableToast] = []
    @Published var gamificationConfig: GamificationConfig?

    private let octopus: OctopusSDK
    private var storage = [AnyCancellable]()
    private var viewStorage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        // The "no connection" toast has no CTA and no timer: it goes away on its own once the
        // connection is back, when the screens silently refresh (Screen states spec).
        octopus.core.connectionAvailablePublisher
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self else { return }
                for toast in toasts where toast.toast == .error(.noNetwork) {
                    remove(toast)
                }
            }.store(in: &storage)

        octopus.core.configRepository.communityConfigPublisher
            .map { $0?.gamificationConfig }
            .removeDuplicates()
            .sink { [unowned self] in
                gamificationConfig = $0
            }.store(in: &storage)
    }

    func viewAppeared() {
        octopus.core.toastsRepository.$toasts
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] in
                guard let self, !$0.isEmpty else { return }
                for toast in $0 {
                    if !toasts.contains(where: { $0.toast == toast }) {
                        show(toast: toast)
                    }
                }
                octopus.core.toastsRepository.consummed(toasts: $0)
            }.store(in: &viewStorage)
    }

    func viewDisappeared() {
        viewStorage = []
    }

    func show(toast: Toast) {
        let displayableToast = DisplayableToast(toast: toast)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            // Errors never stack: a new one replaces the one on screen (Screen states spec). Gamification
            // and user-action toasts are left alone, they are not part of that rule.
            if case .error = toast {
                toasts.removeAll {
                    if case .error = $0.toast { return true }
                    return false
                }
            }
            toasts.append(displayableToast)
        }
        if !displayableToast.isPersistent {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.remove(displayableToast)
            }
        }

        // Post an announcement to the toast content.
        if #available(iOS 17, *) {
            var highPriorityAnnouncement = AttributedString(toast.localizedString(
                locale: octopus.core.languageRepository.overridenLocale))
            highPriorityAnnouncement.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(highPriorityAnnouncement).post()
        }
    }

    func remove(_ toast: DisplayableToast) {
        withAnimation(.easeInOut) {
            toasts.removeAll { $0.id == toast.id }
        }
    }
}
