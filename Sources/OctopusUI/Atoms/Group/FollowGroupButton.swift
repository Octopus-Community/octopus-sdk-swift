//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct FollowGroupButton: View {
    let canChangeFollowStatus: Bool
    let isFollowed: Bool
    let toggleFollow: () -> Void

    var body: some View {
        if canChangeFollowStatus {
            Button(action: {
                toggleFollow()
                HapticFeedback.play()
            }) {
                Text(isFollowed ? "Group.Action.Unfollow" : "Group.Action.Follow", bundle: .module)
            }
            .buttonStyle(OctopusButtonStyle(.mid, style: isFollowed ? .outline : .main))
        }
    }
}
