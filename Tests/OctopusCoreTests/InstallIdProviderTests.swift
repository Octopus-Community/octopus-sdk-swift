//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
@testable import OctopusCore

/// The install id must survive deleting and reinstalling the app, otherwise a device ban is shed by a
/// reinstall. "Reinstalling" is modelled here by building a new provider over a store that kept its
/// contents (the Keychain) while the `UserDefaults`-backed legacy slot did not.
class InstallIdProviderTests: XCTestCase {

    private var legacySlot: UserDefaultsSlot!
    private var markerSlot: UserDefaultsSlot!

    override func setUp() {
        super.setUp()
        legacySlot = UserDefaultsSlot(key: "OctopusSDK.InstallId")
        markerSlot = UserDefaultsSlot(key: "OctopusSDK.InstallId.containerMarker")
        legacySlot.clear()
        markerSlot.clear()
    }

    override func tearDown() {
        legacySlot.clear()
        markerSlot.clear()
        super.tearDown()
    }

    func testGeneratesAndPersistsAnIdOnAFirstInstall() throws {
        let storage = FakeInstallIdStorage()

        let provider = InstallIdProvider(storage: storage)

        XCTAssertFalse(provider.installId.isEmpty)
        XCTAssertEqual(storage.stored, provider.installId)
    }

    /// The acceptance criterion: same id after a reinstall, no new one generated.
    func testKeepsTheSameIdAcrossAReinstall() throws {
        let storage = FakeInstallIdStorage()
        let firstInstall = InstallIdProvider(storage: storage).installId!

        // The app is deleted and reinstalled: the container is gone, the Keychain is not.
        legacySlot.clear()
        markerSlot.clear()
        let afterReinstall = InstallIdProvider(storage: storage).installId!

        XCTAssertEqual(afterReinstall, firstInstall)
        XCTAssertEqual(storage.writeCount, 1, "the id should be written once, not rewritten on every launch")
    }

    /// Existing installs carry their id over on update. Without this, shipping the feature would itself
    /// reset every install id in the wild — and every ban attached to one.
    func testMigratesAnIdLeftInUserDefaultsByAPreviousVersion() throws {
        legacySlot.set("legacy-install-id")
        let storage = FakeInstallIdStorage()

        let provider = InstallIdProvider(storage: storage)

        XCTAssertEqual(provider.installId, "legacy-install-id")
        XCTAssertEqual(storage.stored, "legacy-install-id", "the legacy id should now live in the store")
    }

    /// What is already in the store wins: once migrated, the stale legacy value must not come back.
    func testTheStoredIdWinsOverTheLegacyOne() throws {
        legacySlot.set("legacy-install-id")
        let storage = FakeInstallIdStorage(stored: "keychain-install-id")

        let provider = InstallIdProvider(storage: storage)

        XCTAssertEqual(provider.installId, "keychain-install-id")
    }

    /// An unreadable store (the Keychain before the device's first unlock) is NOT an empty store. Writing
    /// there would overwrite the durable id with a throwaway one and break ban continuity for good.
    func testAnUnreadableStoreIsNeverOverwritten() throws {
        let storage = FakeInstallIdStorage(readError: FakeError.unreadable)

        let provider = InstallIdProvider(storage: storage)

        XCTAssertFalse(provider.installId.isEmpty, "a request still needs an id")
        XCTAssertNil(storage.stored)
        XCTAssertEqual(storage.writeCount, 0)
    }

    /// A store that cannot be written to must still yield a usable id rather than trap.
    func testAFailingWriteStillYieldsAnId() throws {
        let storage = FakeInstallIdStorage(writeError: FakeError.unreadable)

        let provider = InstallIdProvider(storage: storage)

        XCTAssertFalse(provider.installId.isEmpty)
    }

    // MARK: The fresh-install signal that clears the session

    /// A genuinely new container: the session keychain should be cleared.
    func testAFirstInstallIsReportedAsNew() {
        let provider = InstallIdProvider(storage: FakeInstallIdStorage())

        XCTAssertTrue(provider.isNewInstall)
    }

    /// Reinstalling must still log the user out, even though the install id now survives.
    func testAReinstallIsReportedAsNewEvenThoughTheIdSurvives() {
        let storage = FakeInstallIdStorage()
        let firstInstall = InstallIdProvider(storage: storage).installId!
        legacySlot.clear()
        markerSlot.clear()

        let provider = InstallIdProvider(storage: storage)

        XCTAssertTrue(provider.isNewInstall, "the session must still be cleared on a reinstall")
        XCTAssertEqual(provider.installId, firstInstall, "…but the install id must not change")
    }

    func testASecondLaunchIsNotReportedAsNew() {
        let storage = FakeInstallIdStorage()
        _ = InstallIdProvider(storage: storage)

        let provider = InstallIdProvider(storage: storage)

        XCTAssertFalse(provider.isNewInstall)
    }

    /// The regression this guards: an app updating from a version that kept the id in UserDefaults has no
    /// marker yet. Reading that as a fresh install would clear the session of every existing user.
    func testAnUpdateFromAVersionWithoutTheMarkerIsNotReportedAsNew() {
        legacySlot.set("legacy-install-id")

        let provider = InstallIdProvider(storage: FakeInstallIdStorage())

        XCTAssertFalse(provider.isNewInstall)
    }
}

private enum FakeError: Error {
    case unreadable
}

private class FakeInstallIdStorage: InstallIdStorage {
    private(set) var stored: String?
    private(set) var writeCount = 0
    private let readError: Error?
    private let writeError: Error?

    init(stored: String? = nil, readError: Error? = nil, writeError: Error? = nil) {
        self.stored = stored
        self.readError = readError
        self.writeError = writeError
    }

    func installId() throws -> String? {
        if let readError { throw readError }
        return stored
    }

    func store(installId: String) throws {
        if let writeError { throw writeError }
        writeCount += 1
        stored = installId
    }
}

/// Reads and clears the real `UserDefaults` key the provider migrates from.
private class UserDefaultsSlot {
    private let key: String

    init(key: String) { self.key = key }

    func set(_ value: String) { UserDefaults.standard.set(value, forKey: key) }

    func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
