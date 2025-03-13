//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import DependencyInjection
import CryptoKit

extension Injected {
    static let externalLinksRepository = Injector.InjectedIdentifier<ExternalLinksRepository>()
}

public class ExternalLinksRepository: InjectableObject {
    public static let injectedIdentifier = Injected.externalLinksRepository

    public let communityGuidelines: URL
    public let privacyPolicy: URL
    public let termsOfUse: URL
    public let faq: URL
    public let contactUs: URL

    init(injector: Injector, apiKey: String) {
        let hash: String
        if let apiKeyData = apiKey.data(using: .utf8) {
            hash = Insecure.MD5
                .hash(data: apiKeyData)
                .map { String(format: "%02x", $0) }
                .joined()
        } else {
            hash = ""
        }

        let baseUrl = URL(string: "https://redir.8pus.io/")!
        communityGuidelines = baseUrl.appendingPathComponent("guidelines").appendingPathComponent(hash)
        privacyPolicy = baseUrl.appendingPathComponent("privacy").appendingPathComponent(hash)
        termsOfUse = baseUrl.appendingPathComponent("tos").appendingPathComponent(hash)
        faq = baseUrl.appendingPathComponent("faq").appendingPathComponent(hash)
        contactUs = baseUrl.appendingPathComponent("contact").appendingPathComponent(hash)
    }
}
