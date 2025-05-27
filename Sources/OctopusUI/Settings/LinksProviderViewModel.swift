//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

@MainActor
class LinksProviderViewModel: ObservableObject {

    let octopus: OctopusSDK
    let communityGuidelines: URL
    let privacyPolicy: URL
    let termsOfUse: URL
    let faq: URL

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus
        let externalLinksRepository = octopus.core.externalLinksRepository
        communityGuidelines = externalLinksRepository.communityGuidelines
        privacyPolicy = externalLinksRepository.privacyPolicy
        termsOfUse = externalLinksRepository.termsOfUse
        faq = externalLinksRepository.faq
    }
}
