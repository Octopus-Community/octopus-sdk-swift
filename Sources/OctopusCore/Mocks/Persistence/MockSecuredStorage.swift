//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection

class MockSecuredStorage: SecuredStorage, InjectableObject {
    static let injectedIdentifier = Injected.securedStorage

    private var storage: [String: String] = [:]
    /// When set, `value(forKey:)` throws it and the subscript answers `nil`. With
    /// `SecuredStorageError.unavailableUntilFirstUnlock`, the storage behaves like the Keychain before the device's
    /// first unlock and refuses writes too; any other error stands for an unreadable value that can be overwritten.
    var readError: Error?
    /// When set, `readError` is thrown by this many reads only, then goes along with this count: the device being
    /// unlocked right after. A count of 0 or less unlocks it right away, for reads and writes alike.
    var readErrorLastsForReads: Int? {
        didSet {
            guard let readErrorLastsForReads, readErrorLastsForReads <= 0 else { return }
            readError = nil
            self.readErrorLastsForReads = nil
        }
    }

    private var isLocked: Bool {
        guard let readError, case SecuredStorageError.unavailableUntilFirstUnlock = readError else { return false }
        return true
    }

    init() { }

    func value(forKey key: String) throws -> String? {
        guard let readError else { return storage[key] }
        if let readErrorLastsForReads {
            if readErrorLastsForReads > 1 {
                self.readErrorLastsForReads = readErrorLastsForReads - 1
            } else {
                self.readError = nil
                self.readErrorLastsForReads = nil
            }
        }
        throw readError
    }

    func set(_ value: String?, key: String) throws {
        if isLocked { throw SecuredStorageError.unavailableUntilFirstUnlock }
        storage[key] = value
    }

    subscript(key: String) -> String? {
        get { readError == nil ? storage[key] : nil }
        set { if !isLocked { storage[key] = newValue } }
    }
}
