//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

private struct URLOpenerKey: EnvironmentKey {
    static let defaultValue: any URLOpening = NoopURLOpener()
}

extension EnvironmentValues {
    var urlOpener: any URLOpening {
        get { self[URLOpenerKey.self] }
        set { self[URLOpenerKey.self] = newValue }
    }
}
