//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import KeychainAccess
import os

/// Where the install id is persisted.
///
/// Abstracted so `InstallIdProvider` can be unit-tested without a real Keychain, and so the difference
/// between "there is no id yet" and "the store could not be read" stays expressible — conflating the two
/// is what would silently mint a new id and defeat the whole point of persisting it.
protocol InstallIdStorage {
    /// The stored id, or `nil` when nothing has been stored yet.
    /// - Throws: when the store exists but cannot be read.
    func installId() throws -> String?

    func store(installId: String) throws
}

/// Keychain-backed store.
///
/// Deliberately its own Keychain service, separate from the one the connection layer uses: the install id
/// has a different lifetime from a session, and keeping it apart means nothing done to the auth data can
/// take it down with it.
struct KeychainInstallIdStorage: InstallIdStorage {
    private static let key = "installId"

    private let keychain: Keychain

    init(bundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        keychain = Keychain(service: "com.octopus.keychain.installId\(bundleIdentifier.map { ".\($0)" } ?? "")")
            // The most permissive of the sane options: the id is needed on every request, including on a
            // launch triggered in the background, and `whenUnlocked` would make it unreadable there.
            .accessibility(.afterFirstUnlock)
    }

    func installId() throws -> String? {
        try keychain.get(Self.key)
    }

    func store(installId: String) throws {
        try keychain.set(installId, key: Self.key)
    }
}

/// Class that provides an installation id.
///
/// The id **survives deleting and reinstalling the app**, which is what makes a device-level ban
/// effective: iOS keeps Keychain items across an uninstall, so reinstalling no longer hands out a fresh
/// identity. (Before this, the id lived in `UserDefaults` — wiped with the app container — so a
/// delete + reinstall was enough to shed a ban.)
///
/// Two consequences worth knowing:
/// - restoring a new device from an iCloud backup can carry the id over, so both devices report the same
///   install. Accepted: it is still the same person.
/// - the persistence is a de-facto iOS behaviour, not a documented guarantee. Treat a device ban keyed on
///   this id as best-effort, never as something that cannot be escaped.
class InstallIdProvider {
    private(set) var installId: String!

    /// `true` when the app container is brand new: a first install, or a reinstall after a delete.
    ///
    /// Now that `installId` outlives the container, its absence can no longer answer this question — it is
    /// answered by a marker written into the container itself, which iOS does wipe on an uninstall. What
    /// still depends on it: clearing the stored session, so a reinstall logs the user out as it always has,
    /// while the install id itself (kept in a separate Keychain service) survives.
    private(set) var isNewInstall = false

    private let storage: InstallIdStorage
    /// Where the id lived before it moved to the Keychain. Read once, to carry existing installs over.
    @UserDefault(key: "OctopusSDK.InstallId") private var legacyInstallId: String?
    /// Written on first run and wiped with the container, so its absence means "this container is new".
    @UserDefault(key: "OctopusSDK.InstallId.containerMarker", defaultValue: false) private var containerSeen: Bool?

    init(storage: InstallIdStorage = KeychainInstallIdStorage()) {
        self.storage = storage
        installId = resolveInstallId()
        // An app updating from a version that kept the id in UserDefaults has no marker yet, but its
        // container is obviously not new — the legacy id proves it. Without that second test, shipping
        // this would read every existing install as fresh and log all of them out on update.
        isNewInstall = containerSeen != true && legacyInstallId == nil
        if containerSeen != true { containerSeen = true }
    }

    private func resolveInstallId() -> String {
        let stored: String?
        do {
            stored = try storage.installId()
        } catch {
            // The store answered an error rather than "empty" — typically the Keychain being unavailable
            // before the device's first unlock after a reboot. Generating an id is fine (something has to
            // go in the request header), but persisting it is not: it would overwrite the durable id with
            // a throwaway one and break ban continuity for good.
            if #available(iOS 14, *) {
                Logger.other.debug("Install id could not be read (\(error)). Using a transient one.")
            }
            return UUID().uuidString
        }

        if let stored { return stored }

        // Nothing in the Keychain: either a genuinely new install, or an app updating from a version that
        // kept the id in UserDefaults. Carrying the legacy value over matters — minting a new id on update
        // would reset every existing install, along with any ban attached to it.
        let installId = legacyInstallId ?? UUID().uuidString
        do {
            try storage.store(installId: installId)
        } catch {
            if #available(iOS 14, *) {
                Logger.other.debug("Install id could not be persisted: \(error)")
            }
        }
        return installId
    }
}
