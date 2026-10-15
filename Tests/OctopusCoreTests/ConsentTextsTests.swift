//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Testing
import OctopusGrpcModels
@testable import OctopusCore

/// Mapping of `ApiKeyConfig.consentTexts` onto `CommunityConfig.consentTexts`, and its debug-override affordance.
struct ConsentTextsTests {

    // MARK: Mapping

    @Test func absentMessageMapsToNil() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with { $0.displayAccountAge = true }

        #expect(CommunityConfig(from: config).consentTexts == nil)
    }

    @Test func messageWithoutModeMapsToNil() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with { $0.consentTexts = Com_Octopuscommunity_ConsentTexts() }

        #expect(CommunityConfig(from: config).consentTexts == nil)
    }

    @Test func implicitTextsAreMapped() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.consentTexts = .with { $0.implicit = .with { $0.notice = "By posting, [read this](https://a.b)." } }
        }

        #expect(CommunityConfig(from: config).consentTexts
                == .implicit(notice: "By posting, [read this](https://a.b)."))
    }

    @Test func multiCheckboxTextsAreMapped() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.consentTexts = .with {
                $0.multiCheckbox = .with {
                    $0.termsLabel = "Terms"
                    $0.privacyLabel = "Privacy"
                    $0.rulesLabel = "Rules"
                }
            }
        }

        #expect(CommunityConfig(from: config).consentTexts
                == .multiCheckbox(termsLabel: "Terms", privacyLabel: "Privacy", rulesLabel: "Rules"))
    }

    @Test func singleCheckboxTextsAreMapped() {
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.consentTexts = .with {
                $0.singleCheckbox = .with {
                    $0.label = "Label"
                    $0.belowText = "Below"
                }
            }
        }

        #expect(CommunityConfig(from: config).consentTexts == .singleCheckbox(label: "Label", belowText: "Below"))
    }

    @Test(arguments: ["", " ", "\n\t  "])
    func blankFieldsMapToNilButKeepTheirMode(blank: String) {
        let implicit = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.consentTexts = .with { $0.implicit = .with { $0.notice = blank } }
        }
        let multi = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.consentTexts = .with {
                $0.multiCheckbox = .with {
                    $0.termsLabel = blank
                    $0.privacyLabel = "Privacy"
                    $0.rulesLabel = blank
                }
            }
        }
        let single = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.consentTexts = .with {
                $0.singleCheckbox = .with {
                    $0.label = "Label"
                    $0.belowText = blank
                }
            }
        }

        #expect(CommunityConfig(from: implicit).consentTexts == .implicit(notice: nil))
        #expect(CommunityConfig(from: multi).consentTexts
                == .multiCheckbox(termsLabel: nil, privacyLabel: "Privacy", rulesLabel: nil))
        #expect(CommunityConfig(from: single).consentTexts == .singleCheckbox(label: "Label", belowText: nil))
    }

    @Test func customTextIsKeptAsWritten() {
        let notice = "  **Hello**\n\nSecond paragraph with a [link](https://a.b).  "
        let config = Com_Octopuscommunity_ApiKeyConfig.with {
            $0.consentTexts = .with { $0.implicit = .with { $0.notice = notice } }
        }

        #expect(CommunityConfig(from: config).consentTexts == .implicit(notice: notice))
    }

    // MARK: Stored texts

    @Test(arguments: [3, 99, -1])
    func unknownStoredModeMapsToNil(storedMode: Int16) async throws {
        let context = try ConfigCoreDataStack(inRam: true).saveContext

        let (unknown, known) = try await context.performAsync {
            let entity = CommunityConfigEntity(context: context)
            entity.consentImplicitNotice = "Notice"
            entity.consentTextsMode = NSNumber(value: storedMode)
            let unknown = ConsentTexts(from: entity)
            // Control: the same columns do map when the mode is a known one.
            entity.consentTextsMode = NSNumber(value: ConsentTexts.implicit(notice: nil).storageMode)
            return (unknown, ConsentTexts(from: entity))
        }

        #expect(unknown == nil)
        #expect(known == .implicit(notice: "Notice"))
    }

    // MARK: Debug override affordance

    @Test func withConsentTextsReplacesOnlyThatField() {
        let base = CommunityConfig(from: Com_Octopuscommunity_ApiKeyConfig.with {
            $0.displayAccountAge = true
            $0.termsAcceptanceMode = .explicitMultiCheckbox
            $0.showCommentsOnOtherProfiles = true
        })
        let texts = ConsentTexts.multiCheckbox(termsLabel: "T", privacyLabel: nil, rulesLabel: "R")

        let updated = base.withConsentTexts(texts)

        #expect(updated.consentTexts == texts)
        #expect(base.consentTexts == nil)
        #expect(updated.displayAccountAge == base.displayAccountAge)
        #expect(updated.termsAcceptanceMode == base.termsAcceptanceMode)
        #expect(updated.showCommentsOnOtherProfiles == base.showCommentsOnOtherProfiles)
        #expect(updated.forceNicknameChoice == base.forceNicknameChoice)
        #expect(updated.contentOptions == base.contentOptions)
        #expect(updated.profileFieldsLock == base.profileFieldsLock)
    }

    @Test func otherOverridesKeepTheConsentTexts() {
        let texts = ConsentTexts.singleCheckbox(label: "L", belowText: "B")
        let base = CommunityConfig(from: Com_Octopuscommunity_ApiKeyConfig.with { _ in }).withConsentTexts(texts)

        #expect(base.withTermsAcceptanceMode(.explicitSingleCheckbox).consentTexts == texts)
        #expect(base.withProfileFieldsLock(.allEditable).consentTexts == texts)
        #expect(base.withContentOptions(.allEnabled).consentTexts == texts)
        #expect(base.withExposeClientUserId(true).consentTexts == texts)
        #expect(base.withShowCommentsOnOtherProfiles(true).consentTexts == texts)
        #expect(base.withForceNicknameChoice(true).consentTexts == texts)
    }
}
