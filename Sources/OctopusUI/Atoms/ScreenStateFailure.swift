//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// A first load that failed, in the only two shapes the design distinguishes.
///
/// Being offline gets its own picture and wording because the member can act on it; everything else —
/// server down, timeout, unknown — shares one neutral catch-all that says nothing about the network.
enum ScreenStateFailure {
    case noNetwork
    case other

    init(_ error: ServerCallError) {
        if case .noNetwork = error {
            self = .noNetwork
        } else {
            self = .other
        }
    }

    /// Some feed paths throw an untyped error. Anything that is not one of the SDK's own folds into
    /// the neutral catch-all rather than guessing at a network cause.
    init(_ error: Error) {
        if let error = error as? ServerCallError {
            self.init(error)
        } else if let error = error as? AuthenticatedActionError {
            self.init(error)
        } else {
            self = .other
        }
    }

    init(_ error: AuthenticatedActionError) {
        if case .noNetwork = error {
            self = .noNetwork
        } else {
            self = .other
        }
    }
}

extension ScreenStateFailure {
    /// The picture and title to show, both reusing keys that already ship in 24 languages.
    @MainActor
    func screenState(verticalPadding: CGFloat, icons: OctopusTheme.Assets.Icons, retry: @escaping () -> Void)
    -> ScreenState {
        ScreenState(
            image: self == .noNetwork ? icons.screenStates.networkError : icons.screenStates.error,
            title: .localizationKey(self == .noNetwork ? "Error.NoNetwork" : "Error.Unknown"),
            action: .init(title: "Common.Retry", handler: retry),
            verticalPadding: verticalPadding)
    }
}
