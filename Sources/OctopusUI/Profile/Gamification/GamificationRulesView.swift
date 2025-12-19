//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct GamificationRulesScreen: View {
    let gamificationConfig: GamificationConfig
    let gamificationRulesViewManager: GamificationRulesViewManager

    var body: some View {
        GamificationRulesView(gamificationConfig: gamificationConfig)
            .environmentObject(gamificationRulesViewManager)
    }
}

private struct GamificationRulesView: View {
    @EnvironmentObject private var gamificationRulesViewManager: GamificationRulesViewManager

    let gamificationConfig: GamificationConfig

    @State private var contentHeight: CGFloat = .zero

    var body: some View {
        ContentSizedSheet(
            content: { ContentView(gamificationConfig: gamificationConfig) },
            scrollingContent: { ScrollingContentView(gamificationConfig: gamificationConfig) }
        ).onAppear {
            gamificationRulesViewManager.gamificationRulesDisplayed()
        }
    }
}

private struct ScrollingContentView: View {
    @Environment(\.octopusTheme) private var theme

    let gamificationConfig: GamificationConfig

    var body: some View {
        VStack(spacing: 10) {
            if #unavailable(iOS 16.0) {
                Capsule()
                    .fill(theme.colors.gray300)
                    .frame(width: 50, height: 8)
            }
            TitleView()
            ScrollView {
                GamificationRulesExplanationView(gamificationConfig: gamificationConfig)
            }
            PoweredByOctopusView()
        }
        .padding(.top, 40)
        .padding(.horizontal, 16)
    }
}

private struct ContentView: View {
    let gamificationConfig: GamificationConfig

    var body: some View {
        VStack(spacing: 10) {
            TitleView()
            GamificationRulesExplanationView(gamificationConfig: gamificationConfig)
            PoweredByOctopusView()
        }
        .padding(.top, 40)
        .padding(.horizontal, 16)
    }
}

private struct TitleView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            Text("Gamification.Sheet.Title", bundle: .module)
                .font(theme.fonts.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Image(res: .Gamification.rulesHeader)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 40)
                .accessibilityHidden(true)
        }
    }
}

private struct GamificationRulesExplanationView: View {
    @Environment(\.octopusTheme) private var theme

    let gamificationConfig: GamificationConfig

    var body: some View {
        VStack(spacing: 24) {
            if let points = gamificationConfig.pointsByAction[.reaction] {
                RuleExplanationView(
                    text: "Gamification.Sheet.Reaction",
                    points: points,
                    abbrevPointSingular: gamificationConfig.abbrevPointSingular,
                    abbrevPointPlural: gamificationConfig.abbrevPointPlural)
            }

            if let points = gamificationConfig.pointsByAction[.vote] {
                RuleExplanationView(
                    text: "Gamification.Sheet.Vote",
                    points: points,
                    abbrevPointSingular: gamificationConfig.abbrevPointSingular,
                    abbrevPointPlural: gamificationConfig.abbrevPointPlural)
            }

            if let points = gamificationConfig.pointsByAction[.post] {
                RuleExplanationView(
                    text: "Gamification.Sheet.Post",
                    points: points,
                    abbrevPointSingular: gamificationConfig.abbrevPointSingular,
                    abbrevPointPlural: gamificationConfig.abbrevPointPlural)
            }

            if let points = gamificationConfig.pointsByAction[.comment] {
                RuleExplanationView(
                    text: "Gamification.Sheet.Comment",
                    points: points,
                    abbrevPointSingular: gamificationConfig.abbrevPointSingular,
                    abbrevPointPlural: gamificationConfig.abbrevPointPlural)
            }

            if let points = gamificationConfig.pointsByAction[.postCommented] {
                RuleExplanationView(
                    text: "Gamification.Sheet.PostCommented",
                    points: points,
                    abbrevPointSingular: gamificationConfig.abbrevPointSingular,
                    abbrevPointPlural: gamificationConfig.abbrevPointPlural)
            }

            if let points = gamificationConfig.pointsByAction[.dailySession] {
                RuleExplanationView(
                    text: "Gamification.Sheet.DailySession",
                    points: points,
                    abbrevPointSingular: gamificationConfig.abbrevPointSingular,
                    abbrevPointPlural: gamificationConfig.abbrevPointPlural)
            }

            if let points = gamificationConfig.pointsByAction[.profileCompleted] {
                RuleExplanationView(
                    text: "Gamification.Sheet.ProfileCompleted",
                    points: points,
                    abbrevPointSingular: gamificationConfig.abbrevPointSingular,
                    abbrevPointPlural: gamificationConfig.abbrevPointPlural)
            }
        }
        .padding(.vertical, 16)
    }
}

private struct RuleExplanationView: View {
    @Environment(\.octopusTheme) private var theme

    let text: LocalizedStringKey
    let points: Int
    let abbrevPointSingular: String
    let abbrevPointPlural: String

    var body: some View {
        HStack(spacing: 10) {
            Text(text, bundle: .module)
                .font(theme.fonts.body2)
                .fontWeight(.medium)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: "+\(points) \((points > 1 ? abbrevPointPlural : abbrevPointSingular))")
                .font(theme.fonts.body2)
                .fontWeight(.semibold)
        }
    }
}
