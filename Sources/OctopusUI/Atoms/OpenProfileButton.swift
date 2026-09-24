//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct OpenProfileButton<Content: View>: View {
    /// Touch feedback. `.plain` is the historical behaviour — no feedback — and stays the default so
    /// existing call sites are untouched; `.pressOpacity` dims the row while pressed.
    enum Style {
        case plain
        case pressOpacity
    }

    let author: Author
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void
    var style: Style = .plain
    @ViewBuilder let content: Content

    var body: some View {
        let button = Button(action: {
            if let profileId = author.profileId {
                displayProfile(profileId, author.clientUserId)
            }
        }) {
            content
                .contentShape(Rectangle())
        }
        switch style {
        case .plain:
            button.buttonStyle(.plain)
        case .pressOpacity:
            button.buttonStyle(PressOpacityButtonStyle())
        }
    }
}
