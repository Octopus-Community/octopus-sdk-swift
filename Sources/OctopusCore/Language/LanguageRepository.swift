//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let languageRepository = Injector.InjectedIdentifier<LanguageRepository>()
}

public class LanguageRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.languageRepository

    @Published private(set) var localeIdentifier: String = ""
    @Published public private(set) var overridenLocale: Locale? = nil
    @UserDefault(key: "OctopusSDK.Language.overridenLocale") private var overridenLocaleIdentifier: String?

    private var storage = [AnyCancellable]()

    init(injector: Injector) {
        if let overridenLocaleIdentifier {
            overridenLocale = Locale(identifier: overridenLocaleIdentifier)
        }
        $overridenLocale.sink { [unowned self] overridenLocale in
            guard let overridenLocale else {
                localeIdentifier = Bundle.main.preferredLocalizations[0]
                return
            }
            localeIdentifier = overridenLocale.identifier
        }.store(in: &storage)
    }

    public func overrideDefaultLocale(with locale: Locale?) {
        overridenLocale = locale
        overridenLocaleIdentifier = locale?.identifier
    }
}
