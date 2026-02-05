//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .profileModified
    public protocol ProfileModifiedContext: Sendable {
        /// The nickname update information
        var nickname: ProfileFieldUpdate<any NicknameUpdateContext> { get }
        /// The bio update information
        var bio: ProfileFieldUpdate<any BioUpdateContext> { get }
        /// The picture update information
        var picture: ProfileFieldUpdate<any PictureUpdateContext> { get }
    }

    /// Profile field update information
    public enum ProfileFieldUpdate<T: Sendable>: Sendable {
        /// This field has not been modified
        case unchanged
        /// This field has been modified
        case updated(T)

        /// Whether this field has been updated
        public var isUpdated: Bool {
            switch self {
            case .unchanged: return false
            case .updated: return true
            }
        }
    }

    /// The nickname update context. Empty for the moment but can be extended later.
    public protocol NicknameUpdateContext: Sendable { }

    /// The bio update context
    public protocol BioUpdateContext: Sendable {
        /// The length of the bio
        var bioLength: Int { get }
    }

    /// The picture update context
    public protocol PictureUpdateContext: Sendable {
        /// Whether the user has added a picture or deleted the existing one
        var hasPicture: Bool { get }
    }
}

extension SdkEvent.ProfileModifiedContext: OctopusEvent.ProfileModifiedContext {
    public var nickname: OctopusEvent.ProfileFieldUpdate<any OctopusEvent.NicknameUpdateContext> {
        coreNickname.mapToPublic { $0 as OctopusEvent.NicknameUpdateContext }
    }

    public var bio: OctopusEvent.ProfileFieldUpdate<any OctopusEvent.BioUpdateContext> {
        coreBio.mapToPublic { $0 as OctopusEvent.BioUpdateContext }
    }

    public var picture: OctopusEvent.ProfileFieldUpdate<any OctopusEvent.PictureUpdateContext> {
        corePicture.mapToPublic { $0 as OctopusEvent.PictureUpdateContext }
    }
}

extension SdkEvent.ProfileModifiedContext.FieldUpdate {
    /// A cleaner mapping helper that avoids the generic constraint error by using a transformation closure.
    func mapToPublic<PublicType>(_ transform: (T) -> PublicType) -> OctopusEvent.ProfileFieldUpdate<PublicType> {
        switch self {
        case .unchanged:
            return .unchanged
        case .updated(let value):
            return .updated(transform(value))
        }
    }
}

extension SdkEvent.ProfileModifiedContext.NicknameContext: OctopusEvent.NicknameUpdateContext { }
extension SdkEvent.ProfileModifiedContext.BioContext: OctopusEvent.BioUpdateContext { }
extension SdkEvent.ProfileModifiedContext.PictureContext: OctopusEvent.PictureUpdateContext { }
