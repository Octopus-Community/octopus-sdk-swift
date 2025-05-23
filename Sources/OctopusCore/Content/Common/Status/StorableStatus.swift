//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

// Must be the same as `Com_Octopuscommunity_StatusValue`
enum StorableStatus: Equatable {
    case unknown
    case published
    case moderated
    case UNRECOGNIZED(Int16)

    init(rawValue: Int16) {
        self = switch rawValue {
        case StorableStatus.unknown.rawValue: .unknown
        case StorableStatus.published.rawValue: .published
        case StorableStatus.moderated.rawValue: .moderated
        default: .UNRECOGNIZED(rawValue)
        }
    }

    init(from octoStatus: Com_Octopuscommunity_StatusValue) {
        self = switch octoStatus {
        case .unknown:                      .unknown
        case .published:                    .published
        case .moderated:                    .moderated
        case let .UNRECOGNIZED(rawValue):   .UNRECOGNIZED(Int16(rawValue))
        }
    }

    var rawValue: Int16 {
        switch self {
        case .unknown: return 0
        case .published: return 1
        case .moderated: return 2
        case .UNRECOGNIZED(let i): return i
        }
    }
}

struct StorableStatusReason: Equatable {
    enum Code: Equatable {
        case hte
        case hrs
        case gv
        case agg
        case vlc
        case sxc
        case nud
        case soli
        case aex
        case cex
        case ssh
        case ill
        case hex
        case ter
        case hc
        case spm
        case imp
        case mis
        case pii
        case up
        case cip
        case oth
        case UNRECOGNIZED(Int)

        public init(rawValue: Int) {
            switch rawValue {
            case Com_Octopuscommunity_StatusReasonCode.hte.rawValue: self = .hte
            case Com_Octopuscommunity_StatusReasonCode.hrs.rawValue: self = .hrs
            case Com_Octopuscommunity_StatusReasonCode.gv.rawValue: self = .gv
            case Com_Octopuscommunity_StatusReasonCode.agg.rawValue: self = .agg
            case Com_Octopuscommunity_StatusReasonCode.vlc.rawValue: self = .vlc
            case Com_Octopuscommunity_StatusReasonCode.sxc.rawValue: self = .sxc
            case Com_Octopuscommunity_StatusReasonCode.nud.rawValue: self = .nud
            case Com_Octopuscommunity_StatusReasonCode.soli.rawValue: self = .soli
            case Com_Octopuscommunity_StatusReasonCode.aex.rawValue: self = .aex
            case Com_Octopuscommunity_StatusReasonCode.cex.rawValue: self = .cex
            case Com_Octopuscommunity_StatusReasonCode.ssh.rawValue: self = .ssh
            case Com_Octopuscommunity_StatusReasonCode.ill.rawValue: self = .ill
            case Com_Octopuscommunity_StatusReasonCode.hex.rawValue: self = .hex
            case Com_Octopuscommunity_StatusReasonCode.ter.rawValue: self = .ter
            case Com_Octopuscommunity_StatusReasonCode.hc.rawValue: self = .hc
            case Com_Octopuscommunity_StatusReasonCode.spm.rawValue: self = .spm
            case Com_Octopuscommunity_StatusReasonCode.imp.rawValue: self = .imp
            case Com_Octopuscommunity_StatusReasonCode.mis.rawValue: self = .mis
            case Com_Octopuscommunity_StatusReasonCode.pii.rawValue: self = .pii
            case Com_Octopuscommunity_StatusReasonCode.up.rawValue: self = .up
            case Com_Octopuscommunity_StatusReasonCode.cip.rawValue: self = .cip
            case Com_Octopuscommunity_StatusReasonCode.oth.rawValue: self = .oth
            default: self = .UNRECOGNIZED(rawValue)
            }
        }

        public var rawValue: Int {
            switch self {
            case .hte: return Com_Octopuscommunity_StatusReasonCode.hte.rawValue
            case .hrs: return Com_Octopuscommunity_StatusReasonCode.hrs.rawValue
            case .gv: return Com_Octopuscommunity_StatusReasonCode.gv.rawValue
            case .agg: return Com_Octopuscommunity_StatusReasonCode.agg.rawValue
            case .vlc: return Com_Octopuscommunity_StatusReasonCode.vlc.rawValue
            case .sxc: return Com_Octopuscommunity_StatusReasonCode.sxc.rawValue
            case .nud: return Com_Octopuscommunity_StatusReasonCode.nud.rawValue
            case .soli: return Com_Octopuscommunity_StatusReasonCode.soli.rawValue
            case .aex: return Com_Octopuscommunity_StatusReasonCode.aex.rawValue
            case .cex: return Com_Octopuscommunity_StatusReasonCode.cex.rawValue
            case .ssh: return Com_Octopuscommunity_StatusReasonCode.ssh.rawValue
            case .ill: return Com_Octopuscommunity_StatusReasonCode.ill.rawValue
            case .hex: return Com_Octopuscommunity_StatusReasonCode.hex.rawValue
            case .ter: return Com_Octopuscommunity_StatusReasonCode.ter.rawValue
            case .hc: return Com_Octopuscommunity_StatusReasonCode.hc.rawValue
            case .spm: return Com_Octopuscommunity_StatusReasonCode.spm.rawValue
            case .imp: return Com_Octopuscommunity_StatusReasonCode.imp.rawValue
            case .mis: return Com_Octopuscommunity_StatusReasonCode.mis.rawValue
            case .pii: return Com_Octopuscommunity_StatusReasonCode.pii.rawValue
            case .up: return Com_Octopuscommunity_StatusReasonCode.up.rawValue
            case .cip: return Com_Octopuscommunity_StatusReasonCode.cip.rawValue
            case .oth: return Com_Octopuscommunity_StatusReasonCode.oth.rawValue
            case .UNRECOGNIZED(let i): return i
            }
        }
    }

    let code: Code
    let message: String
}

extension StorableStatusReason {
    init(from reason: Com_Octopuscommunity_StatusReason) {
        code = .init(rawValue: reason.code.rawValue)
        message = reason.message
    }
}

extension Array where Element == StorableStatusReason {
    private static let separator = " || "
    init(storableCodes: String, storableMessages: String) {
        let codes = storableCodes.components(separatedBy: Self.separator).compactMap { Int($0) }
        let messages = storableMessages.components(separatedBy: Self.separator)

        self = zip(codes, messages).map { StorableStatusReason(code: .init(rawValue: $0), message: $1) }
    }

    init(from reasons: [Com_Octopuscommunity_StatusReason]) {
        self = reasons.map { StorableStatusReason(from: $0) }
    }

    var storableCodes: String { map { "\($0.code.rawValue)" }.joined(separator: Self.separator) }
    var storableMessages: String { map { $0.message }.joined(separator: Self.separator) }
}
