//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

// The "Presentation modes" scenarios' controls, worded as the Android sample's sections.

private let missingPostId = "No post id — paste one in the field above, then tap again."

struct InitialScreenControls: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            ScenarioLinkRow(title: "Initial screens", subtitle: "Feed, post, group, composer and more",
                            testId: "initialScreen-open") { InitialScreenView() }
            ScenarioLinkRow(title: "Open a profile directly", subtitle: "Member or own profile, by id",
                            testId: "initialScreen-profile-open") { ProfileDirectOpenView() }
        }
    }
}

struct FullscreenControls: View {
    @Binding var route: CommunityRoute?
    @State private var postId = SampleFixtures.postText

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            ScenarioTextField(title: "Post ID (deep-link preset)", text: $postId, testId: "fullscreen-postid-input")
            ModeButton(title: "Preset 1 · Open SDK as full-screen route", testId: "qa-preset-fullscreen-1") {
                route = CommunityRoute()
                ScenarioRunner.instance.record(.fullscreen, result: "Pushed CommunityFullScreenRoute()")
            }
            ModeButton(title: "Preset 2 · Open deep-linked to sample post", testId: "qa-preset-fullscreen-2") {
                let id = postId.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !id.isEmpty else {
                    ScenarioRunner.instance.record(.fullscreen, result: missingPostId, isError: true)
                    return
                }
                route = CommunityRoute(postId: id)
                ScenarioRunner.instance.record(.fullscreen, result: "Pushed CommunityFullScreenRoute(postId=\(id))")
            }
            ModeButton(title: "Preset 3 · Behind a host bottom bar (clears bar + inset)",
                       testId: "qa-preset-fullscreen-3") {
                route = CommunityRoute(showsHostBottomBar: true)
                ScenarioRunner.instance.record(
                    .fullscreen, result: "Pushed CommunityFullScreenRoute(showHostBottomBar=true)")
            }
            // The SDK has no initial screen that opens a comment, so this preset stays visible but disabled.
            ModeButton(title: "Open QA comment on the sample post", isEnabled: false,
                       testId: "fullscreen-open-qa-comment") {}
            RunnerResultLine(id: .fullscreen)
        }
    }
}

/// Modal and bottom sheet: the same two presets, in the container each one names.
struct ContainerControls: View {
    let id: ScenarioID
    let presenter: CommunityPresenter
    @State private var postId = SampleFixtures.postText

    private var containerName: String { id == .modal ? "full-screen modal" : "bottom sheet" }

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            ScenarioTextField(title: "Post ID (deep-link preset)", text: $postId,
                              testId: "\(id.rawValue)-postid-input")
            ModeButton(title: "Preset 1 · Open SDK as \(containerName)", testId: "qa-preset-\(id.rawValue)-1") {
                open(postId: nil)
                ScenarioRunner.instance.record(id, result: "Opened \(containerName)")
            }
            ModeButton(title: "Preset 2 · Open deep-linked to sample post", testId: "qa-preset-\(id.rawValue)-2") {
                let trimmed = postId.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    ScenarioRunner.instance.record(id, result: missingPostId, isError: true)
                    return
                }
                open(postId: trimmed)
                ScenarioRunner.instance.record(
                    id, result: "Opened \(containerName), deep-linked to postId=\(trimmed)")
            }
            RunnerResultLine(id: id)
        }
    }

    private func open(postId: String?) {
        if id == .modal {
            presenter.openModal(postId: postId)
        } else {
            presenter.openSheet(postId: postId)
        }
    }
}
