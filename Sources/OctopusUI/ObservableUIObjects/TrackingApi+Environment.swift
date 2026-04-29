//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

private struct TrackingApiKey: EnvironmentKey {
    static let defaultValue: any TrackingApi = NoopTrackingApi()
}

extension EnvironmentValues {
    var trackingApi: any TrackingApi {
        get { self[TrackingApiKey.self] }
        set { self[TrackingApiKey.self] = newValue }
    }
}
