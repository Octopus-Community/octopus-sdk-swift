//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Combine
@testable import OctopusCore

/// `LanguageChangedMonitor` must point the requests at the new language before reloading the community config, so
/// that the config comes back in that language, and must do it even when the reload fails.
struct LanguageChangedMonitorTests {
    private let latestLanguageKey = "OctopusSDK.latestLanguage"

    @Test func headerIsUpdatedBeforeTheConfigIsReloaded() async throws {
        let suiteName = "LanguageChangedMonitorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("fr", forKey: latestLanguageKey)
        let locale = CurrentValueSubject<String, Never>("fr")
        let calls = CallLog()
        let monitor = makeMonitor(locale: locale, calls: calls, defaults: defaults)
        monitor.start()

        locale.send("en")

        try await expectWithTimeout(calls.entries.contains("refresh"))
        #expect(calls.entries == ["header:fr", "header:en", "reset", "refresh"])
        try await expectWithTimeout(defaults.string(forKey: latestLanguageKey) == "en")
        monitor.stop()
    }

    @Test func headerIsUpdatedEvenWhenTheConfigReloadFails() async throws {
        let suiteName = "LanguageChangedMonitorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("fr", forKey: latestLanguageKey)
        let locale = CurrentValueSubject<String, Never>("fr")
        let calls = CallLog()
        let monitor = makeMonitor(locale: locale, calls: calls, defaults: defaults, refreshFails: true)
        monitor.start()

        locale.send("en")

        try await expectWithTimeout(calls.entries.contains("refresh"))
        #expect(calls.entries.contains("header:en"))
        try await delay()
        // The language is only recorded once the reload worked, so the next launch tries again.
        #expect(defaults.string(forKey: latestLanguageKey) == "fr")
        monitor.stop()
    }

    @Test func firstLaunchRecordsTheLanguageWithoutReloading() async throws {
        let suiteName = "LanguageChangedMonitorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let locale = CurrentValueSubject<String, Never>("fr")
        let calls = CallLog()
        let monitor = makeMonitor(locale: locale, calls: calls, defaults: defaults)
        monitor.start()

        try await delay()

        #expect(calls.entries == ["header:fr"])
        #expect(defaults.string(forKey: latestLanguageKey) == "fr")
        monitor.stop()
    }

    @Test func sameLanguageDoesNotReload() async throws {
        let suiteName = "LanguageChangedMonitorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("fr", forKey: latestLanguageKey)
        let locale = CurrentValueSubject<String, Never>("fr")
        let calls = CallLog()
        let monitor = makeMonitor(locale: locale, calls: calls, defaults: defaults)
        monitor.start()

        try await delay()

        #expect(calls.entries == ["header:fr"])
        monitor.stop()
    }

    private func makeMonitor(locale: CurrentValueSubject<String, Never>, calls: CallLog, defaults: UserDefaults,
                             refreshFails: Bool = false) -> LanguageChangedMonitor {
        LanguageChangedMonitor(
            localeIdentifierPublisher: locale.eraseToAnyPublisher(),
            setLocaleHeader: { calls.append("header:\($0)") },
            resetStoredContent: { calls.append("reset") },
            refreshCommunityConfig: {
                calls.append("refresh")
                if refreshFails { throw RefreshFailure() }
            },
            userDefaults: defaults)
    }
}

private struct RefreshFailure: Error {}

/// Thread-safe record of the monitor's calls, in order.
private final class CallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var entries: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ entry: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(entry)
    }
}
