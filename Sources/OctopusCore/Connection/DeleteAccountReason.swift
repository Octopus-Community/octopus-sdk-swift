//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

public enum DeleteAccountReason: Equatable, CaseIterable, Sendable {
    /// Community content is no more interesting me
    case noMoreInterested
    /// Some key features are missing
    case missingKeyFeatures
    /// I am facing technical issues
    case technicalIssues
    /// I am worrying about confidentiality of my data
    case confidentialityWorrying
    /// I am not satisfied about moderation service or community quality
    case communityQuality
    /// I want to reduce my time spent on social networks
    case reducingSnTime
    /// Other
    case other
}

extension DeleteAccountReason {
    var protoValue: Com_Octopuscommunity_DeleteMyProfileRequest.DeleteMyProfileReason {
        .with {
            $0.code = switch self {
            case .noMoreInterested:         .noMoreInterested
            case .missingKeyFeatures:       .missingKeyFeatures
            case .technicalIssues:          .technicalIssues
            case .confidentialityWorrying:  .confidentialityWorrying
            case .communityQuality:         .communityQuality
            case .reducingSnTime:           .reducingSnTime
            case .other:                    .other
            }
        }
    }
}
