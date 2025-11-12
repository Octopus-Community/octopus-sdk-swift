//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import OctopusCore

struct ValidateNicknameFlowNavigationStack<RootView: View>: View {
    let octopus: OctopusSDK
    @Compat.StateObject private var flowPath: ValidateNicknameFlowPath
    @ViewBuilder let rootView: RootView

    init(octopus: OctopusSDK, flowPath: ValidateNicknameFlowPath,
         @ViewBuilder _ rootView: () -> RootView) {
        self.octopus = octopus
        _flowPath = Compat.StateObject(wrappedValue: flowPath)
        self.rootView = rootView()
    }

    var body: some View {
        NBNavigationStack(path: $flowPath.path) {
            rootView
                .nbNavigationDestination(for: ValidateNicknameFlowScreen.self) { screen in
                    switch screen {
                    case .editProfile:
                        EditProfileView(octopus: octopus, bioFocused: false, photoPickerFocused: false,
                                        preventDismissAfterUpdate: true)
                    }
                }
        }
        .nbUseNavigationStack(.whenAvailable)
    }
}
