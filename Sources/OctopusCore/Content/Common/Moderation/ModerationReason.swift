//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

public enum ModerationReason: Equatable, Sendable, Hashable {
    /// Hateful Conduct
    case hatefulConduct
    /// Bullying or Harassment
    case bullyingOrHarassment
    /// Graphic Violence
    case graphicViolence
    /// Aggressive
    case aggressive
    /// Violent Instigation
    case violentInstigation
    /// Sexually Suggestive
    case sexuallySuggestive
    /// Adult Nudity or Sexual Activity
    case adultNudityOrSexualActivity
    /// Sexual Solicitation or Explicit Language
    case sexualSolicitationOrExplicitLanguage
    /// Adult Sexual Exploitation
    case adultSexualExploitation
    /// Child Sexual Abuse Material
    case childSexualAbuseMaterial
    /// Suicide or Self-harm
    case suicideOrSelfHarm
    /// Regulated Goods
    case regulatedGoods
    /// Human Exploitation
    case humanExploitation
    /// Terrorism, Organized Hate, Dangerous Organizations or Individual
    case terrorismOrganizedHateDangerousOrganizationsOrIndividual
    /// Harm or Crime
    case harmOrCrime
    /// Spam or Scams
    case spamOrScams
    /// Impersonation
    case impersonation
    /// Misinformation
    case misinformation
    /// Personally Identifiable Information
    case personallyIdentifiableInformation
    /// Username Policy
    case usernamePolicy
    /// Copyright or Intellectual Property Infringement
    case copyrightOrIntellectualPropertyInfringement
    /// Other reasons
    case other(String?)
}
