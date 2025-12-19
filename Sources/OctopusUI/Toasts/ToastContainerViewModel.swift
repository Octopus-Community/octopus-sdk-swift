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
            .sink { [unowned self] in
                guard !$0.isEmpty else { return }
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
            toasts.append(displayableToast)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.remove(displayableToast)
        }

        // Post an announcement to the toast content.
        if #available(iOS 17, *) {
            var highPriorityAnnouncement = AttributedString(toast.localizedString)
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
