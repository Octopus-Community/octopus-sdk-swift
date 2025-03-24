//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus

struct OpenUserProfileBubbleView: View {
    @Compat.StateObject private var viewModel: OpenUserProfileBubbleViewModel

    let userProfileTapped: () -> Void

    init(octopus: OctopusSDK, userProfileTapped: @escaping () -> Void) {
        _viewModel = Compat.StateObject(wrappedValue: OpenUserProfileBubbleViewModel(octopus: octopus))
        self.userProfileTapped = userProfileTapped
    }

    var body: some View {
        Button(action: userProfileTapped) {
            AuthorAvatarView(avatar: viewModel.avatar)
        }
        .buttonStyle(.plain)
    }
}
