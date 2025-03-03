//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct AuthorActionView: View {
    let octopus: OctopusSDK
    let actionKind: CreateButton.Kind
    let userProfileTapped: () -> Void
    let actionTapped: () -> Void

    var body: some View {
        HStack {
            OpenUserProfileBubbleView(octopus: octopus, userProfileTapped: userProfileTapped)
                .frame(width: 50, height: 50)
            CreateButton(kind: actionKind, actionTapped: actionTapped)
        }
//        .padding(.bottom, 8)
        .padding(.horizontal)
    }
}
