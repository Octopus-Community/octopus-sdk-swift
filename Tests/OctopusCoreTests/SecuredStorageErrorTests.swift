//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Security
import Testing
import KeychainAccess
@testable import OctopusCore

/// What KeychainAccess throws. OctopusCore has a `Status` of its own.
private typealias KeychainStatus = KeychainAccess.Status

/// Everything that tells a locked device from an absent value hangs on this mapping: were it to stop matching what
/// KeychainAccess throws, every read before the first unlock would count as "nothing stored" again. The errors the
/// Security framework answers are built the way KeychainAccess builds them, from their `OSStatus`.
struct SecuredStorageErrorTests {

    @Test func theKeychainBeforeTheFirstUnlockIsUnavailable() {
        let error = SecuredStorageError.from(keychainError: KeychainStatus(status: errSecInteractionNotAllowed))

        guard case SecuredStorageError.unavailableUntilFirstUnlock = error else {
            Issue.record("Expected unavailableUntilFirstUnlock, got \(error)")
            return
        }
    }

    /// A missing entitlement, a value the Keychain cannot decode, an unavailable Keychain: no wait for the unlock
    /// would cure them. The arguments are raw `OSStatus` values because `KeychainAccess.Status` is not `Sendable`.
    @Test(arguments: [errSecMissingEntitlement, errSecDecode, errSecNotAvailable])
    func anyOtherKeychainErrorIsKeptAsIs(osStatus: OSStatus) {
        let status = KeychainStatus(status: osStatus)

        let error = SecuredStorageError.from(keychainError: status)

        #expect(error as? KeychainStatus == status)
    }

    /// What KeychainAccess throws itself, not answered by the Security framework, for a stored value that is not
    /// valid UTF-8.
    @Test func anUndecodableValueIsKeptAsIs() {
        let error = SecuredStorageError.from(keychainError: KeychainStatus.conversionError)

        #expect(error as? KeychainStatus == .conversionError)
    }
}
