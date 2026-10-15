//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(CommunityConfigEntity)
class CommunityConfigEntity: NSManagedObject, Identifiable {
    @NSManaged public var forceLoginOnStrongActions: Bool
    @NSManaged public var displayAccountAge: Bool
    @NSManaged public var exposeClientUserId: Bool
    @NSManaged public var showCommentsOnOtherProfiles: Bool
    @NSManaged public var forceNicknameChoice: Bool
    @NSManaged public var nicknameLock: Int16
    @NSManaged public var avatarLock: Int16
    @NSManaged public var bioLock: Int16
    @NSManaged public var postEnablePictures: Bool
    @NSManaged public var postEnablePolls: Bool
    @NSManaged public var postTextRequired: Bool
    @NSManaged public var commentEnablePictures: Bool
    @NSManaged public var replyEnablePictures: Bool
    @NSManaged public var termsAcceptanceMode: Int16
    /// Case of the stored consent texts (`ConsentTexts.storageMode`), `nil` when the community set none.
    @NSManaged public var consentTextsMode: NSNumber?
    @NSManaged public var consentImplicitNotice: String?
    @NSManaged public var consentTermsLabel: String?
    @NSManaged public var consentPrivacyLabel: String?
    @NSManaged public var consentRulesLabel: String?
    @NSManaged public var consentSingleLabel: String?
    @NSManaged public var consentBelowText: String?
    @NSManaged public var gamificationConfig: GamificationConfigEntity?
    @NSManaged public var displayConfig: DisplayConfigEntity?

    func fill(with config: CommunityConfig, context: NSManagedObjectContext) {
        forceLoginOnStrongActions = config.forceLoginOnStrongActions
        displayAccountAge = config.displayAccountAge
        exposeClientUserId = config.exposeClientUserId
        showCommentsOnOtherProfiles = config.showCommentsOnOtherProfiles
        forceNicknameChoice = config.forceNicknameChoice
        nicknameLock = config.profileFieldsLock.nickname.storageValue
        avatarLock = config.profileFieldsLock.avatar.storageValue
        bioLock = config.profileFieldsLock.bio.storageValue
        postEnablePictures = config.contentOptions.post.enablePictures
        postEnablePolls = config.contentOptions.post.enablePolls
        postTextRequired = config.contentOptions.post.textRequired
        commentEnablePictures = config.contentOptions.comment.enablePictures
        replyEnablePictures = config.contentOptions.reply.enablePictures
        termsAcceptanceMode = config.termsAcceptanceMode.storageValue
        fillConsentTexts(config.consentTexts)
        gamificationConfig = config.gamificationConfig.map { gamificationConfig in
            let entity = GamificationConfigEntity(context: context)
            entity.fill(with: gamificationConfig, context: context)
            return entity
        }
        displayConfig = config.displayConfig.map { displayConfig in
            let entity = DisplayConfigEntity(context: context)
            entity.fill(with: displayConfig, context: context)
            return entity
        }
    }

    /// Stores the consent texts in their columns. The columns of the other cases are cleared, because `upsert`
    /// updates the existing row: an update must not keep texts the server no longer sends.
    private func fillConsentTexts(_ texts: ConsentTexts?) {
        consentTextsMode = texts.map { NSNumber(value: $0.storageMode) }
        consentImplicitNotice = nil
        consentTermsLabel = nil
        consentPrivacyLabel = nil
        consentRulesLabel = nil
        consentSingleLabel = nil
        consentBelowText = nil
        switch texts {
        case let .implicit(notice)?:
            consentImplicitNotice = notice
        case let .multiCheckbox(termsLabel, privacyLabel, rulesLabel)?:
            consentTermsLabel = termsLabel
            consentPrivacyLabel = privacyLabel
            consentRulesLabel = rulesLabel
        case let .singleCheckbox(label, belowText)?:
            consentSingleLabel = label
            consentBelowText = belowText
        case nil:
            break
        }
    }
}

// Extension that adds all fetch requests needed
extension CommunityConfigEntity {
    @nonobjc public class func fetch() -> NSFetchRequest<CommunityConfigEntity> {
        let request = NSFetchRequest<CommunityConfigEntity>(entityName: "CommunityConfig")
        request.fetchLimit = 1
        return request
    }
}
