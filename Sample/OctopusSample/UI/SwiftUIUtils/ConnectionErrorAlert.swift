//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus

extension OctopusConnectUserError {
    var userFriendlyDescription: String {
        switch self {
        case let .userBanned(message):
            return "Your account has been banned: \(message)"
        case let .profileError(errors):
            let descriptions = errors.map { error in
                let field = error.field.map { "\($0)" } ?? "profile"
                return "\(field): \(error.message)"
            }
            return "Profile update failed:\n\(descriptions.joined(separator: "\n"))"
        case .jwtError:
            return "Authentication failed: the provided token is invalid. Please check your token provider."
        case .communityAccessDenied:
            return "You do not have access to the community."
        case .noNetwork:
            return "No internet connection. Please check your network and try again."
        case .server:
            return "A server error occurred. Please try again later."
        case .other:
            return "An unexpected error occurred. Please try again."
        }
    }
}

private struct ConnectionErrorAlertModifier: ViewModifier {
    @State private var connectionError: OctopusConnectUserError?
    @State private var displayError = false

    func body(content: Content) -> some View {
        content
            .onReceive(AppUserManager.instance.$connectionError) { error in
                connectionError = error
                displayError = error != nil
            }
            .alert(isPresented: $displayError, content: {
                Alert(
                    title: Text("Connection Error (displayed by the app)"),
                    message: Text(connectionError?.userFriendlyDescription ?? "Unknown error"),
                    dismissButton: .default(Text("OK")) {
                        AppUserManager.instance.connectionError = nil
                    })
            })
    }
}

extension View {
    func connectionErrorAlert() -> some View {
        modifier(ConnectionErrorAlertModifier())
    }
}
