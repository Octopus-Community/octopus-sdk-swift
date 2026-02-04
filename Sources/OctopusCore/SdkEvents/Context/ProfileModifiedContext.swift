//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct ProfileModifiedContext: Sendable {
        /// The nickname update information
        public let coreNickname: FieldUpdate<NicknameContext>
        /// The bio update information
        public let coreBio: FieldUpdate<BioContext>
        /// The picture update information
        public let corePicture: FieldUpdate<PictureContext>

        public enum FieldUpdate<T: Sendable>: Sendable {
            case unchanged
            case updated(T)

            var isUpdated: Bool {
                switch self {
                case .unchanged: return false
                case .updated: return true
                }
            }
        }

        /// The nickname update context
        public struct NicknameContext: Sendable { }

        /// The bio update context
        public struct BioContext: Sendable {
            /// The length of the bio
            public let bioLength: Int
        }

        /// The picture update context
        public struct PictureContext: Sendable {
            /// Whether the user has added a picture or deleted the existing one
            public let hasPicture: Bool
        }

        public init(profile: EditableProfile) {
            coreNickname = switch profile.nickname {
            case .unchanged: .unchanged
            case .updated: .updated(.init())
            }
            coreBio = switch profile.bio {
            case .unchanged: .unchanged
            case let .updated(value): .updated(.init(bioLength: value?.count ?? 0))
            }
            corePicture = switch profile.picture {
            case .unchanged: .unchanged
            case let .updated(value): .updated(.init(hasPicture: value != nil))
            }
        }
    }
}
