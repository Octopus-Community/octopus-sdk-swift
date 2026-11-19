//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import Foundation
import SwiftUI
import Testing
@testable import OctopusCore
@testable import OctopusUI

/// How the SDK picks the version of a text that matches the member's tone, and keeps the tone up to date.
@MainActor
struct TextToneDisplayTests {
    private let french = Locale(identifier: "fr")

    @Test func aTonedTextIsResolvedInTheToneOfTheMember() {
        let text = DisplayableString.noNetworkError

        #expect(text.localizedString(locale: french, tone: .formal)
                == "Pas de connexion internet. Veuillez vérifier votre connexion.")
        #expect(text.localizedString(locale: french, tone: .informal)
                == "Pas de connexion internet. Vérifie ta connexion.")
    }

    @Test func aTextThatDoesNotAddressTheMemberIgnoresTheTone() {
        let text = DisplayableString.localizationKey("Common.Retry")

        #expect(text.localizedString(locale: french, tone: .informal)
                == text.localizedString(locale: french, tone: .formal))
    }

    @Test func aLanguageWithASingleFormShowsTheSameTextInBothTones() {
        let english = Locale(identifier: "en")
        let text = DisplayableString.noNetworkError

        #expect(text.localizedString(locale: english, tone: .informal)
                == text.localizedString(locale: english, tone: .formal))
    }

    @Test func theVoiceOverAnnouncementOfAToastFollowsTheTone() {
        let toast = Toast.gamification(GamificationToast(action: .reaction, formattedPoints: "+5 pts"))

        #expect(toast.localizedString(locale: french, tone: .formal).contains("Votre réaction"))
        #expect(toast.localizedString(locale: french, tone: .informal).contains("Ta réaction"))
    }

    @Test func theLanguageManagerPublishesTheToneItIsGiven() {
        let tones = PassthroughSubject<TextTone, Never>()
        let manager = LanguageManager(overridenLocalePublisher: Just(nil).eraseToAnyPublisher(),
                                      textTonePublisher: tones.eraseToAnyPublisher())
        #expect(manager.textTone == .formal)

        tones.send(.informal)
        #expect(manager.textTone == .informal)

        tones.send(.formal)
        #expect(manager.textTone == .formal)
    }

    @Test func theToneFollowsTheConfigAndTheDisplayedLanguage() {
        let informalLanguages = CurrentValueSubject<[String], Never>([])
        let languageIdentifier = CurrentValueSubject<String, Never>("fr")
        let manager = LanguageManager(
            overridenLocalePublisher: Just(nil).eraseToAnyPublisher(),
            textTonePublisher: LanguageManager.textTone(
                informalLanguages: informalLanguages.eraseToAnyPublisher(),
                languageIdentifier: languageIdentifier.eraseToAnyPublisher()))
        #expect(manager.textTone == .formal)

        // The back office makes French informal.
        informalLanguages.send(["fr"])
        #expect(manager.textTone == .informal)

        // The app forces English, then French again.
        languageIdentifier.send("en")
        #expect(manager.textTone == .formal)
        languageIdentifier.send("fr-CA")
        #expect(manager.textTone == .informal)

        // The back office goes back to formal.
        informalLanguages.send([])
        #expect(manager.textTone == .formal)
    }

    @Test func previewsAndScreensOutsideTheSdkAreFormal() {
        #expect(EnvironmentValues().textTone == .formal)
        #expect(LanguageManager.forPreviews().textTone == .formal)
    }
}
