//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine

class MainFlowPath: ObservableObject {
    @Published var path: [MainFlowScreen] = []

    /// The currently-presented report target (drives the report sheet at the navigation root).
    @Published var reportTarget: ReportTarget?

    /// Emits the id of a profile that was reported, then blocked from the "Report sent" alert, so that this
    /// profile's screen closes, as it does when the profile is blocked from its own menu. Blocking the author
    /// after a content report never emits: the screen the content was reported from stays open.
    let profileBlockedAfterReport = PassthroughSubject<String, Never>()
}
