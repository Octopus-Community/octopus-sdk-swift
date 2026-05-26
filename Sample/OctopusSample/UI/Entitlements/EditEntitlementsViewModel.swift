//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// View model for the connected-user entitlement editor flow.
///
/// Initial selection is sourced from the SDK-published `OctopusProfile.entitlements` (the
/// BE-resolved truth). On save the new set is written to `AppUserManager.currentEntitlements`
/// and `octopus.refreshEntitlements()` is called — a fresh JWT is minted with the new
/// claims, the BE issues a new Octopus JWT, and the published profile reflects the result.
@MainActor
class EditEntitlementsViewModel: ObservableObject {
    @Published var selection: Set<Entitlement>
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let octopus: OctopusSDK?
    private var storage = [AnyCancellable]()

    init() {
        let octopus = OctopusSDKProvider.instance.octopus
        self.octopus = octopus
        self.selection = Self.entitlements(from: octopus?.profile?.entitlements)

        octopus?.$profile
            .map { Self.entitlements(from: $0?.entitlements) }
            .removeDuplicates()
            .sink { [weak self] in
                // Only adopt SDK-side updates while the user hasn't started editing yet.
                // Once the user toggles a checkbox, their working set takes precedence.
                guard let self, !self.userHasEdited else { return }
                self.selection = $0
            }
            .store(in: &storage)
    }

    private(set) var userHasEdited = false
    func markEdited() { userHasEdited = true }

    func save() async -> Bool {
        guard let octopus else {
            errorMessage = "SDK not initialized."
            return false
        }
        AppUserManager.instance.currentEntitlements = selection
        isSaving = true
        defer { isSaving = false }
        do {
            try await octopus.refreshEntitlements()
            return true
        } catch {
            // do not display the debug description in your app, either treat it silently or map it to a user friendly
            // message
            errorMessage = error.debugDescription
            return false
        }
    }

    private static func entitlements(from raw: Set<String>?) -> Set<Entitlement> {
        guard let raw else { return [] }
        return Set(raw.compactMap { Entitlement(rawValue: $0) })
    }
}
