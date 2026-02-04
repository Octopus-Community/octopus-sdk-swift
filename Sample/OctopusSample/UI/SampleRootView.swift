//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusUI
import Octopus
import OctopusCore

/// Root view of the sample. In non-internal demo mode, it will display directly the SampleTabView
struct SampleRootView: View {
    @State private var displaySDKConfig = DefaultValuesProvider.internalDemoMode && SDKConfigManager.instance.sdkConfig == nil

    var body: some View {
        Group {
            if displaySDKConfig {
                SDKConfigScreen()
            } else {
                SampleTabView()
            }
        }
        .onReceive(SDKConfigManager.instance.$sdkConfig) {
            displaySDKConfig = DefaultValuesProvider.internalDemoMode && $0 == nil
        }
    }
}

#Preview {
    SampleRootView()
}
