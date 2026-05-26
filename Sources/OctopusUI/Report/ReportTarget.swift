//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Identifies what is being reported when the report sheet is presented.
enum ReportTarget: Identifiable, Equatable {
    case content(contentId: String)
    case profile(profileId: String)

    var id: String {
        switch self {
        case .content(let contentId): return "content:\(contentId)"
        case .profile(let profileId): return "profile:\(profileId)"
        }
    }
}
