//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

@MainActor
class ReportViewModel: ObservableObject {
    /// What is reported. `blockableProfileId` is the profile the "Report sent" alert offers to block, as
    /// computed by the call site (see `ReportTarget`), `nil` for no offer.
    enum Context {
        case content(contentId: String, blockableProfileId: String?)
        case profile(profileId: String, blockableProfileId: String?)

        var isContent: Bool {
            switch self {
            case .content: true
            case .profile: false
            }
        }

        var blockableProfileId: String? {
            switch self {
            case .content(_, let blockableProfileId), .profile(_, let blockableProfileId): blockableProfileId
            }
        }
    }

    /// What the view model needs from the SDK, as closures so that tests can drive it without a backend.
    ///
    /// The closures deliberately use an *untyped* `throws`: a typed `throws` inside a stored function type
    /// crashes below iOS 18 once `ObservableObject` reflects over it (see `ReactionsListManager.Fetch`).
    /// `ReportViewModel` re-types what they throw.
    struct Dependencies {
        /// Sends the report.
        let report: (_ context: Context, _ reasons: [ReportReason]) async throws -> Void
        /// Blocks a profile.
        let blockUser: (_ profileId: String) async throws -> Void
        /// The viewer's profile id and the profiles they already blocked, `nil` when no profile is connected.
        let currentUser: () -> (id: String, blockedProfileIds: [String])?
    }

    /// Raised while the report, then the block offered after it, is in flight: shows the loading overlay and
    /// keeps the screen from sending anything else.
    @Published private(set) var moderationInProgress = false
    @Published private(set) var error: DisplayableString?
    @Published var moderationSent = false

    /// The profile the "Report sent" alert offers to block, set when the report succeeds. `nil` means no offer.
    @Published private(set) var profileIdToBlock: String?
    /// Set once the block offered after the report succeeded: shows the "This user is blocked" alert.
    @Published var blockDone = false
    /// Whether the screen closes once the current error is dismissed. Only a failed block closes it:
    /// the report is already sent, there is nothing left to do on this screen.
    private(set) var closeAfterError = false

    let context: Context

    private let dependencies: Dependencies

    convenience init(octopus: OctopusSDK, context: Context) {
        let core = octopus.core
        self.init(context: context, dependencies: Dependencies(
            report: { context, reasons in
                switch context {
                case .content(let contentId, _):
                    try await core.moderationRepository.reportContent(contentId: contentId, reasons: reasons)
                case .profile(let profileId, _):
                    try await core.moderationRepository.reportUser(profileId: profileId, reasons: reasons)
                }
            },
            blockUser: { try await core.profileRepository.blockUser(profileId: $0) },
            currentUser: {
                core.profileRepository.profile.map { (id: $0.id, blockedProfileIds: $0.blockedProfileIds) }
            }))
    }

    /// Designated init. Takes the SDK calls directly so that tests can serve them without a full `OctopusSDK`.
    init(context: Context, dependencies: Dependencies) {
        self.context = context
        self.dependencies = dependencies
    }

    func report(reasons: [ReportReason]) {
        Task {
            await report(reasons: reasons)
        }
    }

    /// Blocks the profile offered by the "Report sent" alert. The report is already sent: a failure
    /// never cancels it, and blocking sends no other report. `moderationInProgress` is raised before the task
    /// starts, so a second tap in the same run-loop turn cannot send a second block.
    func blockProfile() {
        guard let profileIdToBlock, !moderationInProgress, !blockDone else { return }
        moderationInProgress = true
        Task {
            await blockProfile(profileId: profileIdToBlock)
        }
    }

    private func report(reasons: [ReportReason]) async {
        moderationInProgress = true
        do {
            try await dependencies.report(context, reasons)
            profileIdToBlock = Self.profileIdToBlock(context: context, currentUser: dependencies.currentUser())
            moderationSent = true
            moderationInProgress = false
        } catch {
            moderationInProgress = false
            self.error = Self.displayableMessage(error)
        }
    }

    private func blockProfile(profileId: String) async {
        defer { moderationInProgress = false }
        do {
            try await dependencies.blockUser(profileId)
            blockDone = true
        } catch {
            closeAfterError = true
            self.error = Self.displayableMessage(error)
        }
    }

    /// The profile the "Report sent" alert offers to block: the call site's blockable profile, unless the
    /// viewer already blocked it: an already-blocked profile can still be opened and reported.
    private static func profileIdToBlock(context: Context,
                                         currentUser: (id: String, blockedProfileIds: [String])?) -> String? {
        guard let profileId = context.blockableProfileId, let currentUser else { return nil }
        guard !currentUser.blockedProfileIds.contains(profileId) else { return nil }
        return profileId
    }

    /// Re-types what `Dependencies` had to widen to `any Error`: the SDK calls throw an
    /// `AuthenticatedActionError`.
    private static func displayableMessage(_ error: Error) -> DisplayableString {
        let actionError = error as? AuthenticatedActionError ?? .other(error)
        return actionError.displayableMessage
    }
}
