//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct AuthorActionView: View {
    let octopus: OctopusSDK
    let actionKind: CreateButton.Kind
    let displayCreateButton: Bool
    let isScrollingDown: Bool
    let userProfileTapped: () -> Void
    let actionTapped: () -> Void

    init(octopus: OctopusSDK,
         actionKind: CreateButton.Kind,
         displayCreateButton: Bool,
         isScrollingDown: Bool = false,
         userProfileTapped: @escaping () -> Void,
         actionTapped: @escaping () -> Void) {
        self.octopus = octopus
        self.actionKind = actionKind
        self.displayCreateButton = displayCreateButton
        self.isScrollingDown = isScrollingDown
        self.userProfileTapped = userProfileTapped
        self.actionTapped = actionTapped
    }

    var body: some View {
        HStack {
            OpenUserProfileBubbleView(octopus: octopus, userProfileTapped: userProfileTapped)
                .frame(width: 50, height: 50)
            Spacer()
            if displayCreateButton {
                CreateButton(kind: actionKind, isReduced: isScrollingDown, actionTapped: actionTapped)
            }
        }
        .padding(.horizontal)
    }
}
