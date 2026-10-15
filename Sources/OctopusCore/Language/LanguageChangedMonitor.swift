//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusDependencyInjection
import os
import OctopusRemoteClient

extension Injected {
    static let languageChangedMonitor = Injector.InjectedIdentifier<LanguageChangedMonitor>()
}

/// Monitor that saves and compare the current language of the SDK to the previous one. If they are different, it
/// resets the update timestamp of every content in order to re-download them with the new translation
final class LanguageChangedMonitor: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.languageChangedMonitor

    private let localeIdentifierPublisher: AnyPublisher<String, Never>
    private let setLocaleHeader: (String) -> Void
    private let resetStoredContent: @Sendable () async throws -> Void
    private let refreshCommunityConfig: @Sendable () async throws -> Void
    private let userDefaults: UserDefaults
    private let latestLanguageKey = "OctopusSDK.latestLanguage"

    private var storage = [AnyCancellable]()

    init(injector: Injector) {
        let octoObjectsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        let configRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        let languageRepository = injector.getInjected(identifiedBy: Injected.languageRepository)
        let remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        localeIdentifierPublisher = languageRepository.$localeIdentifier.eraseToAnyPublisher()
        setLocaleHeader = { remoteClient.set(localeIdentifier: $0) }
        resetStoredContent = { try await octoObjectsDatabase.resetUpdateTimestamp() }
        refreshCommunityConfig = { try await configRepository.refreshCommunityConfig() }
        userDefaults = .standard
    }

    /// Test-only init: accepts the language publisher, the calls and the defaults directly.
    init(localeIdentifierPublisher: AnyPublisher<String, Never>,
         setLocaleHeader: @escaping (String) -> Void,
         resetStoredContent: @escaping @Sendable () async throws -> Void,
         refreshCommunityConfig: @escaping @Sendable () async throws -> Void,
         userDefaults: UserDefaults) {
        self.localeIdentifierPublisher = localeIdentifierPublisher
        self.setLocaleHeader = setLocaleHeader
        self.resetStoredContent = resetStoredContent
        self.refreshCommunityConfig = refreshCommunityConfig
        self.userDefaults = userDefaults
    }

    func start() {
        // The sink and its task capture `self` weakly, not unowned: the task can start once this monitor is gone (a
        // community switch releases the previous core). Without the monitor, the language change is left to the next
        // one, which compares against the language stored here.
        localeIdentifierPublisher.removeDuplicates().sink { [weak self] currentLanguage in
            guard let self else { return }
            // The header goes first, whatever happens next: the config reload below, and every request after it,
            // must ask the server for the new language, even when that reload fails.
            setLocaleHeader(currentLanguage)
            guard let lastLanguage = userDefaults.string(forKey: latestLanguageKey) else {
                userDefaults.set(currentLanguage, forKey: latestLanguageKey)
                return
            }
            guard lastLanguage != currentLanguage else { return }
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await resetStoredContent()
                    try await refreshCommunityConfig()
                    userDefaults.set(currentLanguage, forKey: latestLanguageKey)
                    if #available(iOS 14, *) { Logger.content.debug("Done reseting stored data due to language change") }
                } catch {
                    if #available(iOS 14, *) {
                        Logger.content.trace("Error while reseting stored data due to language change: \(error)")
                    }
                }
            }
        }.store(in: &storage)
    }

    func stop() {
        storage = []
    }
}
