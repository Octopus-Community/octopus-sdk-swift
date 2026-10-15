//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

// The "Community & groups" scenarios' controls, worded as the Android sample's sections.

struct GroupsControls: View {
    @ObservedObject private var live = ScenarioLiveState.instance
    @ObservedObject private var runner = ScenarioRunner.instance
    @State private var query = ""

    private var filtered: [OctopusGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return live.groups }
        return live.groups.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            LiveFlowDisplay(label: "groups", value: countLine)
            ScenarioTextField(title: "Filter groups", placeholder: "e.g. Announcements, News, Premium…",
                              text: $query, testId: "groups-filter-input")
            if filtered.isEmpty, !query.isEmpty {
                Text("No group matches '\(query)'")
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
            }
            ForEach(filtered, id: \.id) { group in
                GroupRow(group: group)
            }
            ApiMethodCard(name: "fetchGroups()", description: "Fetch fresh groups from server",
                          isRunning: runner.calls[.groups]?.isLoading == true, testId: "qa-preset-groups-1") {
                ScenarioRunActions.run(.groups, route: .constant(nil))
            }
        }
    }

    private var countLine: String {
        query.isEmpty ? "\(live.groups.count) group(s) cached"
            : "\(filtered.count) of \(live.groups.count) group(s) match"
    }
}

private struct GroupRow: View {
    let group: OctopusGroup

    private var state: String {
        guard group.canChangeFollowStatus else { return "Managed by server" }
        return group.isFollowed ? "Followed" : "Not followed"
    }

    var body: some View {
        HStack(spacing: SampleTokens.Spacing.space3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(SampleTokens.Typography.bodyStrong)
                    .foregroundColor(SampleTokens.Colors.text)
                Text(state)
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(group.isFollowed ? SampleTokens.Colors.successText
                                     : SampleTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if group.canChangeFollowStatus {
                Button(group.isFollowed ? "Unfollow" : "Follow") {
                    let follow = !group.isFollowed
                    ScenarioRunner.instance.run(.groups) {
                        let results = try await OctopusSDKProvider.instance.octopus.syncFollowGroups(actions: [
                            .init(groupId: group.id, followed: follow, actionDate: Date()),
                        ])
                        return "\(follow ? "Follow" : "Unfollow") \(group.name): " +
                            SyncFollowSummary.describe(results)
                    }
                }
                .font(SampleTokens.Typography.label)
                .foregroundColor(SampleTokens.Colors.accentText)
                .frame(minHeight: SampleTokens.Size.touchMin)
                .accessibilityId("groups-row-follow-\(group.id)")
            }
        }
        .padding(.horizontal, SampleTokens.Spacing.space3)
        .sampleCardSurface(cornerRadius: SampleTokens.Radius.medium)
    }
}

enum SyncFollowSummary {
    static func describe(_ results: [OctopusSyncFollowGroup.Result]) -> String {
        guard !results.isEmpty else { return "no action sent" }
        var counts = [String: Int]()
        for result in results { counts[name(result.status), default: 0] += 1 }
        return counts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    }

    static func name(_ status: OctopusSyncFollowGroup.Status) -> String {
        switch status {
        case .applied: "Applied"
        case .skipped: "Skipped"
        case .groupNotFound: "GroupNotFound"
        case .notFollowable: "NotFollowable"
        case .notUnfollowable: "NotUnfollowable"
        case .alreadyFollowed: "AlreadyFollowed"
        case .alreadyUnfollowed: "AlreadyUnfollowed"
        case .unknownError: "UnknownError"
        @unknown default: "Unknown"
        }
    }
}

struct SyncFollowGroupsControls: View {
    @ObservedObject private var runner = ScenarioRunner.instance
    @State private var offsetMinutes = 0

    private enum Kind { case invert, followAll, unfollowAll }

    var body: some View {
        let isRunning = runner.calls[.syncFollowGroups]?.isLoading == true
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            Text("actionDate offset")
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.textSecondary)
            Picker("actionDate offset", selection: $offsetMinutes) {
                Text("now − 5 min").tag(-5)
                Text("now").tag(0)
                Text("now + 5 min").tag(5)
            }
            .pickerStyle(.segmented)
            .accessibilityId("syncFollowGroups-offset")
            ApiMethodCard(name: "invert all",
                          description: "Invert follow state for every controllable group. Exercises Applied " +
                              "(both directions) + Skipped (with past offset).",
                          isRunning: isRunning, testId: "qa-preset-syncFollowGroups-1") { sync(.invert) }
            ApiMethodCard(name: "FOLLOW all",
                          description: "Send `followed = true` for every controllable group. Exercises " +
                              "AlreadyFollowed + Applied.",
                          isRunning: isRunning, testId: "qa-preset-syncFollowGroups-2") { sync(.followAll) }
            ApiMethodCard(name: "UNFOLLOW all",
                          description: "Send `followed = false` for every controllable group. Exercises " +
                              "AlreadyUnfollowed + Applied.",
                          isRunning: isRunning, testId: "qa-preset-syncFollowGroups-3") { sync(.unfollowAll) }
        }
    }

    private func sync(_ kind: Kind) {
        let date = Date().addingTimeInterval(TimeInterval(offsetMinutes * 60))
        ScenarioRunner.instance.run(.syncFollowGroups) {
            let octopus = OctopusSDKProvider.instance.octopus!
            if octopus.groups.isEmpty { try await octopus.fetchGroups() }
            let actions = octopus.groups.filter(\.canChangeFollowStatus).map { group in
                let followed = switch kind {
                case .invert: !group.isFollowed
                case .followAll: true
                case .unfollowAll: false
                }
                return OctopusSyncFollowGroup.Action(groupId: group.id, followed: followed, actionDate: date)
            }
            let results = try await octopus.syncFollowGroups(actions: actions)
            return "\(actions.count) action(s): " + SyncFollowSummary.describe(results)
        }
    }
}

struct CommunityAccessControls: View {
    @ObservedObject private var overrides = ScenarioOverrides.instance
    @ObservedObject private var live = ScenarioLiveState.instance
    @ObservedObject private var runner = ScenarioRunner.instance

    var body: some View {
        let isLoading = runner.calls[.communityAccess]?.isLoading == true
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "Community-access signals your app supplies to the SDK. overrideCommunityAccess is " +
                "enforced by the SDK; track(hasAccessToCommunity:) is analytics-only. There is no reset call for " +
                "the override — re-apply the other value to reverse it.")
            if let access = overrides.communityAccess {
                OverrideActiveBadge(label: access ? "Override active · granted" : "Override active · denied",
                                    testId: "communityAccess-override-badge")
            }
            ModeButton(title: "Override · grant access", isSelected: overrides.communityAccess == true,
                       isEnabled: !isLoading, testId: "qa-preset-communityAccess-1") { override(true) }
            ModeButton(title: "Override · deny access", isSelected: overrides.communityAccess == false,
                       isEnabled: !isLoading, testId: "qa-preset-communityAccess-2") { override(false) }
            SecondaryPillButton(title: "Track · has access", testId: "qa-preset-communityAccess-3") {
                OctopusSDKProvider.instance.octopus.track(hasAccessToCommunity: true)
                ScenarioRunner.instance.record(.communityAccess, result: "Success: tracked hasAccessToCommunity=true")
            }
            LiveFlowDisplay(label: "hasAccessToCommunity", value: "\(live.hasAccessToCommunity)")
        }
    }

    private func override(_ access: Bool) {
        ScenarioRunner.instance.run(.communityAccess) {
            try await OctopusSDKProvider.instance.octopus.overrideCommunityAccess(access)
            ScenarioOverrides.instance.communityAccess = access
            return "Success: overrideCommunityAccess(\(access))"
        }
    }
}

struct BridgeControls: View {
    let presenter: CommunityPresenter

    var body: some View {
        ScenarioLinkRow(title: "Open the product catalog", subtitle: "Each product opens its bridged post",
                        testId: "bridge-open") {
            BridgeToClientObjectView(showFullScreen: presenter.showFullScreen)
        }
    }
}

struct CreatePostControls: View {
    var body: some View {
        ScenarioLinkRow(title: "Open the composer presets", subtitle: "Text, image or link handed over by the host",
                        testId: "createPost-open") { InitialScreenView() }
    }
}

struct ReactionsControls: View {
    @State private var postId = ""

    private static let presets: [(label: String, kind: OctopusReactionKind?, resultLabel: String)] = [
        ("Preset 1 · React heart", .heart, "Preset 1 · React heart"),
        ("Preset 2 · Change reaction to joy", .joy, "Preset 2 · Change reaction to joy"),
        ("Preset 3 · Unreact (null)", nil, "Preset 3 · Unreact"),
        ("Preset 4 · React mouthOpen", .mouthOpen, "Preset 4 · React mouthOpen"),
        ("Preset 5 · React clap", .clap, "Preset 5 · React clap"),
        ("Preset 6 · React cry", .cry, "Preset 6 · React cry"),
        ("Preset 7 · React rage", .rage, "Preset 7 · React rage"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "set(reaction:postId:) — set, change or clear the current user's reaction on an " +
                "EXISTING post. Paste a post id below (e.g. one opened from the Bridge scenario, or copied from " +
                "the community feed); no post is ever created here.")
            ScenarioTextField(title: "Post ID", text: $postId, testId: "reactions-postid-input")
            ForEach(Array(Self.presets.enumerated()), id: \.offset) { index, preset in
                ModeButton(title: preset.label, isEnabled: !postId.trimmingCharacters(in: .whitespaces).isEmpty,
                           testId: "qa-preset-reactions-\(index + 1)") {
                    react(preset.resultLabel, preset.kind)
                }
            }
            RunnerResultLine(id: .reactions, placeholder: "none yet — paste a post id and tap a preset.")
        }
    }

    private func react(_ label: String, _ kind: OctopusReactionKind?) {
        let id = postId.trimmingCharacters(in: .whitespacesAndNewlines)
        ScenarioRunner.instance.run(.reactions) {
            do {
                try await OctopusSDKProvider.instance.octopus.set(reaction: kind, postId: id)
                return "\(label) -> OK"
            } catch {
                throw ScenarioFailure("\(label) -> Error: \(error)")
            }
        }
    }
}

struct GroupAccessDeniedControls: View {
    @ObservedObject private var manager = GroupAccessDeniedManager.instance

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "The host's group-access-denied callback, used when a member reaches a group they " +
                "cannot open. \"Register\" here only counts fires below — it never navigates. \"Unregister\" " +
                "installs a real no-op.")
            if let mode = manager.scenarioMode {
                OverrideActiveBadge(label: mode == .counting ? "Registered" : "Unregistered (no-op)",
                                    testId: "groupAccessDenied-badge")
            }
            ModeButton(title: "Register callback", isSelected: manager.scenarioMode == .counting,
                       testId: "qa-preset-groupAccessDenied-1") { manager.setScenarioMode(.counting) }
            ModeButton(title: "Unregister callback", isSelected: manager.scenarioMode == .noop,
                       testId: "qa-preset-groupAccessDenied-2") { manager.setScenarioMode(.noop) }
            LiveFlowDisplay(label: "fired", value: "\(manager.scenarioFireCount)")
            ScenarioResultLine(text: resultLine, testId: "groupAccessDenied-result")
        }
    }

    private var resultLine: String? {
        switch manager.scenarioMode {
        case .counting?: "Success: callback registered (fired \(manager.scenarioFireCount) time(s))"
        case .noop?: "Success: callback set to no-op (unregister substitute)"
        case nil: nil
        }
    }
}

struct ScreenStatesControls: View {
    var body: some View {
        ScenarioLinkRow(title: "Open the screen states", subtitle: "Loading, empty and error states",
                        testId: "screenStates-open") { ScreenStatesView() }
    }
}

struct GroupSectionsControls: View {
    var body: some View {
        ScenarioLinkRow(title: "Open the group sections", subtitle: "Groups split into topic sections",
                        testId: "groupSections-open") { GroupSectionsView() }
    }
}
