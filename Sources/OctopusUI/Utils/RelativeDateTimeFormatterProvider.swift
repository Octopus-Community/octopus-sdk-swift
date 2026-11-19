//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

class RelativeDateTimeFormatterProvider {

    private(set) var formatter: RelativeDateTimeFormatter
    /// The formatter of the dates in the header of posts, comments and replies.
    let contentDateFormatter = ContentDateFormatter()

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .short

        octopus.core.languageRepository.$overridenLocale.sink { [unowned self] overridenLocale in
            if let overridenLocale {
                formatter.locale = overridenLocale
                contentDateFormatter.locale = overridenLocale
            }
        }.store(in: &storage)
    }
}
