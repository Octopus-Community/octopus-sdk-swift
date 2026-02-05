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

    private let octoObjectsDatabase: OctoObjectsDatabase
    private let configRepository: ConfigRepository
    private let languageRepository: LanguageRepository
    private let remoteClient: OctopusRemoteClient
    private let userDefaults = UserDefaults.standard
    private let latestLanguageKey = "OctopusSDK.latestLanguage"

    private var storage = [AnyCancellable]()

    init(injector: Injector) {
        octoObjectsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        configRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        languageRepository = injector.getInjected(identifiedBy: Injected.languageRepository)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
    }

    func start() {
        languageRepository.$localeIdentifier.removeDuplicates().sink { [unowned self] currentLanguage in
            if let lastLanguage = userDefaults.string(forKey: latestLanguageKey) {
                if lastLanguage != currentLanguage {
                    Task {
                        do {
                            try await octoObjectsDatabase.resetUpdateTimestamp()
                            try await configRepository.refreshCommunityConfig()
                            remoteClient.set(localeIdentifier: currentLanguage)
                            userDefaults.set(currentLanguage, forKey: latestLanguageKey)
                            if #available(iOS 14, *) { Logger.content.debug("Done reseting stored data due to language change") }
                        } catch {
                            if #available(iOS 14, *) { Logger.content.trace("Error while reseting stored data due to language change: \(error)") }
                        }
                    }
                }
            } else {
                userDefaults.set(currentLanguage, forKey: latestLanguageKey)
            }
        }.store(in: &storage)
    }

    func stop() {
        storage = []
    }
}
