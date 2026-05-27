//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

@MainActor
class ReportViewModel: ObservableObject {
    enum Context {
        case content(contentId: String)
        case profile(profileId: String)

        var isContent: Bool {
            switch self {
            case .content: true
            case .profile: false
            }
        }
    }

    @Published private(set) var moderationInProgress = false
    @Published private(set) var error: DisplayableString?
    @Published var moderationSent = false

    let octopus: OctopusSDK
    let context: Context

    init(octopus: OctopusSDK, context: Context) {
        self.octopus = octopus
        self.context = context
    }

    func report(reasons: [ReportReason]) {
        Task {
            await report(reasons: reasons)
        }
    }

    private func report(reasons: [ReportReason]) async {
        moderationInProgress = true
        do {
            switch context {
            case .content(let contentId):
                try await octopus.core.moderationRepository.reportContent(contentId: contentId, reasons: reasons)
            case .profile(let profileId):
                try await octopus.core.moderationRepository.reportUser(profileId: profileId, reasons: reasons)
            }
            moderationSent = true
            moderationInProgress = false
        } catch {
            moderationInProgress = false
            self.error = error.displayableMessage
        }
    }
}
