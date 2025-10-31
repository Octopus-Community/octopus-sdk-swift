//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusDependencyInjection
import os

extension Injected {
    static let languageChangedMonitor = Injector.InjectedIdentifier<LanguageChangedMonitor>()
}

/// Monitor that saves and compare the current language of the SDK to the previous one. If they are different, it
/// resets the update timestamp of every content in order to re-download them with the new translation
final class LanguageChangedMonitor: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.languageChangedMonitor

    private let database: OctoObjectsDatabase
    private let userDefaults = UserDefaults.standard
    private let latestLanguageKey = "OctopusSDK.latestLanguage"

    @Published private var isSendingEvents: Bool = false

    init(injector: Injector) {
        database = injector.getInjected(identifiedBy: Injected.postsDatabase)
    }

    func start() {
        let currentLanguage = Bundle.main.preferredLocalizations[0]
        if let lastLanguage = userDefaults.string(forKey: latestLanguageKey) {
            if lastLanguage != currentLanguage {
                Task {
                    do {
                        try await database.resetUpdateTimestamp()
                        userDefaults.set(currentLanguage, forKey: latestLanguageKey)
                        if #available(iOS 14, *) { Logger.content.debug("Done reseting update timestamp due to language change") }
                    } catch {
                        if #available(iOS 14, *) { Logger.content.trace("Error while reseting update timestamp: \(error)") }
                    }
                }
            }
        } else {
            userDefaults.set(currentLanguage, forKey: latestLanguageKey)
        }
    }

    func stop() {

    }
}
