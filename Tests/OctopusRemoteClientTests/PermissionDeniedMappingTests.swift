//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import Foundation
import GRPC
@testable import OctopusRemoteClient

/// `PERMISSION_DENIED` carries the server's own explanation of why an action was refused — the member is
/// meant to read it. It used to fall into `default` and become `.unknown`, which the UI renders as a
/// generic message: the wording was written, translated, and then dropped on iOS only.
@Suite("RemoteClientError.permissionDenied")
struct PermissionDeniedMappingTests {

    @Test func permissionDeniedCarriesTheServerMessage() {
        let error = RemoteClientError(
            error: GRPCStatus(code: .permissionDenied, message: "You cannot post in this group."))

        guard case let .permissionDenied(reason) = error else {
            Issue.record("expected .permissionDenied, got \(error)")
            return
        }
        #expect(reason == "You cannot post in this group.")
    }

    @Test func permissionDeniedWithoutMessageHasNoReason() {
        let error = RemoteClientError(error: GRPCStatus(code: .permissionDenied, message: nil))

        guard case let .permissionDenied(reason) = error else {
            Issue.record("expected .permissionDenied, got \(error)")
            return
        }
        // The UI falls back to a dedicated string on nil; an empty one would render as a blank alert.
        #expect(reason == nil)
    }

    @Test func permissionDeniedWithEmptyMessageHasNoReason() {
        let error = RemoteClientError(error: GRPCStatus(code: .permissionDenied, message: ""))

        guard case let .permissionDenied(reason) = error else {
            Issue.record("expected .permissionDenied, got \(error)")
            return
        }
        // An empty server message must not reach the alert as an empty string.
        #expect(reason == nil)
    }

    @Test func otherStatusesAreUnaffected() {
        guard case .notFound = RemoteClientError(error: GRPCStatus(code: .notFound, message: "x")) else {
            Issue.record("notFound should still map to .notFound")
            return
        }
        guard case .unknown = RemoteClientError(error: GRPCStatus(code: .internalError, message: "x")) else {
            Issue.record("unhandled codes should still map to .unknown")
            return
        }
    }
}
