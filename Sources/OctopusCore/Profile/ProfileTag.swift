//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

public struct ProfileTags: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let admin = ProfileTags(rawValue: 1 << 0)

    public static let all: ProfileTags = [.admin]
}

extension ProfileTags {
    init(from tag: Com_Octopuscommunity_ProfileTag) {
        self = switch tag {
        case .admin: .admin
        case let .UNRECOGNIZED(value):
            if value < 64 {
                ProfileTags(rawValue: 1 << value)
            } else {
                []
            }
        case .undefined: []
        }
    }

    init(from tags: [Com_Octopuscommunity_ProfileTag]) {
        var profileTags: ProfileTags = []
        for tag in tags {
            profileTags.insert(.init(from: tag))
        }
        self = profileTags
    }
}
