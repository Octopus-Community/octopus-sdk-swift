//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// How the community requires users to accept its legal documents (terms, privacy policy, community
/// rules) at their first contribution.
///
/// - `implicit`: today's default — a legal disclaimer is shown at the bottom of the editor and
///   acceptance is implicit when the user publishes. Unchanged for every existing community.
/// - `explicitMultiCheckbox`: a bottom sheet with **one checkbox per legal document** (all required)
///   is shown at the first contribution; publishing is gated until every box is checked.
/// - `explicitSingleCheckbox`: same bottom sheet with **a single combined checkbox** (plus a passive
///   privacy-policy acknowledgement); publishing is gated until that box is checked.
///
/// The two explicit modes share the same behaviour (trigger, memorization, dismissal) and differ
/// only in the sheet's content (number of checkboxes + wordings).
public enum TermsAcceptanceMode: Sendable, Equatable {
    case implicit
    case explicitMultiCheckbox
    case explicitSingleCheckbox

    /// Whether this mode presents the explicit-consent bottom sheet (i.e. anything but `.implicit`).
    public var isExplicit: Bool {
        switch self {
        case .implicit: return false
        case .explicitMultiCheckbox, .explicitSingleCheckbox: return true
        }
    }
}

extension TermsAcceptanceMode {
    /// Maps the proto enum. Unknown/unset values default to `.implicit` (proto3 default ⇒ graceful
    /// degradation: today's behaviour for communities that have not enabled an explicit mode).
    init(from proto: Com_Octopuscommunity_TermsAcceptanceMode) {
        switch proto {
        case .implicit: self = .implicit
        case .explicitMultiCheckbox: self = .explicitMultiCheckbox
        case .explicitSingleCheckbox: self = .explicitSingleCheckbox
        case .UNRECOGNIZED: self = .implicit
        }
    }

    /// Stable CoreData raw value. `0` (default for new/migrated rows) ⇒ `.implicit` ⇒ no-op.
    var storageValue: Int16 {
        switch self {
        case .implicit: 0
        case .explicitMultiCheckbox: 1
        case .explicitSingleCheckbox: 2
        }
    }

    init(storageValue: Int16) {
        switch storageValue {
        case 1: self = .explicitMultiCheckbox
        case 2: self = .explicitSingleCheckbox
        default: self = .implicit
        }
    }
}
