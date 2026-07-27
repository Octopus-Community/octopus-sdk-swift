//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct OpenProfileButton<Content: View>: View {
    let author: Author
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: {
            if let profileId = author.profileId {
                displayProfile(profileId, author.clientUserId)
            }
        }) {
            content
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
