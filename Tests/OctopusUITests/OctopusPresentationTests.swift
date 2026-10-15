//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Testing
import UIKit
@testable import OctopusUI

/// What the `octopus…` presentation modifiers rely on: `sharedEnvironmentObjects(_:)` must inject every shared object
/// and expose them to presenters, so that presented content never depends on SwiftUI passing the presenter's
/// environment down (which an iPad app running on a Mac does too late: reading an `@EnvironmentObject` then traps).
///
/// The presentations themselves are not exercised here: the test host has no window scene to present from.
@Suite(.serialized)
@MainActor
struct OctopusPresentationTests {

    @Test func sharedEnvironmentObjectsInjectsEveryObject() async throws {
        let objects = makeObjects()
        let recorder = Recorder()

        try await renderInWindow(EnvironmentObjectsProbe(recorder: recorder).sharedEnvironmentObjects(objects),
                                 until: { recorder.didRender })

        #expect(recorder.receivedIds == objects.ids)
    }

    @Test func sharedEnvironmentObjectsAreReadableByPresenters() async throws {
        let objects = makeObjects()
        let recorder = Recorder()

        try await renderInWindow(SharedEnvironmentObjectsKeyProbe(recorder: recorder).sharedEnvironmentObjects(objects),
                                 until: { recorder.didRender })

        #expect(recorder.receivedIds == objects.ids)
    }

    @Test func noSharedEnvironmentObjectsOutsideTheEntryScreens() async throws {
        let recorder = Recorder()

        try await renderInWindow(SharedEnvironmentObjectsKeyProbe(recorder: recorder), until: { recorder.didRender })

        #expect(recorder.receivedIds.isEmpty)
    }

    // MARK: - Helpers

    private func makeObjects() -> SharedEnvironmentObjects {
        SharedEnvironmentObjects(
            translationStore: .forPreviews(),
            gamificationRulesViewManager: .forPreviews(),
            displayConfigManager: .forPreviews(),
            reactionsListManager: .forPreviews(),
            videoManager: .forPreviews(),
            languageManager: .forPreviews())
    }
}

@MainActor
private final class Recorder {
    var didRender = false
    var receivedIds: [ObjectIdentifier] = []
}

/// Reads the six objects the way the SDK's screens do: as `@EnvironmentObject`, which traps when one is missing.
private struct EnvironmentObjectsProbe: View {
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore
    @EnvironmentObject private var gamificationRulesViewManager: GamificationRulesViewManager
    @EnvironmentObject private var displayConfigManager: DisplayConfigManager
    @EnvironmentObject private var reactionsListManager: ReactionsListManager
    @EnvironmentObject private var videoManager: VideoManager
    @EnvironmentObject private var languageManager: LanguageManager

    let recorder: Recorder

    var body: some View {
        recorder.didRender = true
        recorder.receivedIds = [
            ObjectIdentifier(translationStore),
            ObjectIdentifier(gamificationRulesViewManager),
            ObjectIdentifier(displayConfigManager),
            ObjectIdentifier(reactionsListManager),
            ObjectIdentifier(videoManager),
            ObjectIdentifier(languageManager),
        ]
        return Color.clear
    }
}

/// Reads the objects the way a presentation modifier does: from the environment value.
private struct SharedEnvironmentObjectsKeyProbe: View {
    @Environment(\.sharedEnvironmentObjects) private var objects

    let recorder: Recorder

    var body: some View {
        recorder.didRender = true
        recorder.receivedIds = objects?.ids ?? []
        return Color.clear
    }
}

private extension SharedEnvironmentObjects {
    var ids: [ObjectIdentifier] {
        [
            ObjectIdentifier(translationStore),
            ObjectIdentifier(gamificationRulesViewManager),
            ObjectIdentifier(displayConfigManager),
            ObjectIdentifier(reactionsListManager),
            ObjectIdentifier(videoManager),
            ObjectIdentifier(languageManager),
        ]
    }
}
