//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

/// The Scenarios tab root, laid out as the Android sample's list: a pinned search, the "Open the community" card,
/// the live community config, then the collapsible scenario groups. The shell (`SampleTabView`) hosts it in its own
/// navigation container, so this view has none: the scenario cards push onto the tab's stack.
struct ScenariosView: View {
    let showFullScreen: (@escaping () -> any View) -> Void
    let showInSheet: (@escaping () -> any View) -> Void

    @ObservedObject private var toggles = FeatureToggles.instance
    @State private var query = ""
    @State private var expanded = Set<ScenarioSection>()
    @State private var route: CommunityRoute?

    private var presenter: CommunityPresenter {
        CommunityPresenter(showFullScreen: showFullScreen, showInSheet: showInSheet)
    }

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        let groups = ScenarioCatalog.filtered(query)
        ScrollView {
            // A plain VStack, not a LazyVStack: the list is a few dozen cards at most, and a lazy stack livelocked
            // the main thread here. Clearing the search collapses the groups and re-inserts the two top cards, so
            // the lazy stack's estimated content height changed under a scrolled offset; the scroll view then
            // re-adjusted its offset, which brought other variable-height rows into view, which changed the
            // estimate again, without end. An eager stack measures every row once and has no estimate to chase.
            VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
                if !isSearching {
                    OpenCommunityCard(presenter: presenter, onOpenFullScreen: { route = CommunityRoute() })
                    LiveCommunityConfigCard()
                        .accessibilityElement(children: .contain)
                        .accessibilityId("scenarios-live-community-config")
                }
                ForEach(groups, id: \.section) { group in
                    ScenarioSectionBlock(
                        section: group.section,
                        specs: group.scenarios,
                        isExpanded: isSearching || expanded.contains(group.section),
                        presenter: presenter) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expanded.contains(group.section) {
                                    expanded.remove(group.section)
                                } else {
                                    expanded.insert(group.section)
                                }
                            }
                        }
                }
                if groups.isEmpty {
                    Text("No scenario matches \"\(query)\".")
                        .font(SampleTokens.Typography.callout)
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityId("scenarios-empty")
                }
            }
            .padding(.horizontal, SampleTokens.Spacing.gutter)
            // Android: the search field and the list are 16 apart (`spacedBy(space4)`).
            .padding(.top, SampleTokens.Spacing.space4)
            .padding(.bottom, SampleTokens.Spacing.space6)
        }
        .accessibilityId("scenarios-screen")
        .safeAreaInset(edge: .top, spacing: 0) { searchField }
        .sampleScreenBackground()
        .communityRoute($route)
        .sampleTabRoot("Scenarios")
        .hostAppFooter()
        .onAppear { SampleTabRouter.instance.lastContentBreadcrumb = "Scenarios" }
        // Android rebuilds the list when its tab is left, so the groups come back collapsed: leaving the tab
        // collapses them here too.
        .onReceive(SampleTabRouter.instance.$selectedTab) { tab in
            if tab != .scenarios { expanded.removeAll() }
        }
    }

    /// Android's `OutlinedTextField` radius. Material's outlined field sits below the sample's radius scale, which
    /// starts at `Radius.small` (6), so it stays a named constant here rather than a sample-wide token.
    private static let outlinedFieldRadius: CGFloat = 4

    /// Android's `OutlinedTextField`: a 56-tall box with a 4 radius and a 1 outline over the screen background (no
    /// fill of its own), under the 8 the floating label reserves above it, so the field takes 64.
    private var searchField: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: SampleTokens.Size.iconSmall))
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .frame(width: SampleTokens.Size.touchMin)
                .accessibilityHidden(true)
            TextField("Search scenarios", text: $query)
                .font(SampleTokens.Typography.body)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .accessibilityId("scenarios-search-input")
            if isSearching {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                }
                .accessibilityLabelCompat("Clear search")
                .accessibilityId("scenarios-search-clear")
                .padding(.leading, SampleTokens.Spacing.space2)
            }
        }
        .padding(.trailing, SampleTokens.Spacing.space4)
        .frame(minHeight: SampleTokens.Size.rowMin)
        .overlay(
            RoundedRectangle(cornerRadius: Self.outlinedFieldRadius, style: .continuous)
                .strokeBorder(SampleTokens.Colors.outline, lineWidth: 1))
        .padding(.horizontal, SampleTokens.Spacing.gutter)
        // 16 above the box: the 8 Android's floating label reserves, plus the 8 between the field and the top bar.
        .padding(.top, SampleTokens.Spacing.space4)
        .background(SampleTokens.Colors.background.ignoresSafeArea(edges: .horizontal))
    }
}

/// The first scenario of the list: the same community in each of the four containers a host offers it.
private struct OpenCommunityCard: View {
    let presenter: CommunityPresenter
    let onOpenFullScreen: () -> Void

    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        ScenarioBlock(title: "Open the community", systemImage: "bubble.left.and.bubble.right.fill", tryTone: true) {
            VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
                Text("The same community, in the container your app gives it.")
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                // At the accessibility text sizes a half-width pill breaks its title mid-word: one per row then.
                if sizeCategory.isAccessibilityCategory {
                    tabButton
                    modalButton
                    sheetButton
                    fullScreenButton
                } else {
                    HStack(spacing: SampleTokens.Spacing.space2) {
                        tabButton
                        modalButton
                    }
                    HStack(spacing: SampleTokens.Spacing.space2) {
                        sheetButton
                        fullScreenButton
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityId("scenarios-open-community-card")
    }

    private var tabButton: some View {
        PrimaryPillButton(title: "Tab", testId: "open-community-tab-button") { presenter.openTab() }
    }

    private var modalButton: some View {
        SecondaryPillButton(title: "Modal", testId: "open-community-modal-button") { presenter.openModal() }
    }

    private var sheetButton: some View {
        SecondaryPillButton(title: "Sheet", testId: "open-community-sheet-button") { presenter.openSheet() }
    }

    private var fullScreenButton: some View {
        SecondaryPillButton(title: "Full screen", testId: "open-community-fullscreen-button",
                            action: onOpenFullScreen)
    }
}

/// One collapsible group: its header (title, feature switch, count, chevron), then its scenario cards.
private struct ScenarioSectionBlock: View {
    let section: ScenarioSection
    let specs: [ScenarioSpec]
    let isExpanded: Bool
    let presenter: CommunityPresenter
    let onToggle: () -> Void

    /// How far the chevron's touch target reaches past its glyph on each side (12): no more than the header's
    /// horizontal padding (`space3`), and the header is at least `touchMin` tall, so the target stays inside it.
    private static let chevronSlop = (SampleTokens.Size.touchMin - SampleTokens.Size.icon) / 2

    @ObservedObject private var toggles = FeatureToggles.instance

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            header
            if isExpanded {
                ForEach(specs, id: \.id) { spec in
                    ScenarioCard(spec: spec, presenter: presenter)
                }
            }
        }
    }

    /// The group's feature switch, always shown as on Android; it is disabled where this build cannot act on it
    /// (force login outside the demo SSO configuration).
    private var featureToggle: FeatureToggle? { section.toggle }

    /// Android `ScenarioSectionHeader`: surfaceVariant at 0.4 alpha, radius 12, padding 12 x 10, min height 48.
    private var header: some View {
        HStack(spacing: SampleTokens.Spacing.space2) {
            Button(action: onToggle) {
                HStack(spacing: SampleTokens.Spacing.space2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(Font.subheadline.weight(.bold))
                            .foregroundColor(SampleTokens.Colors.text)
                        if let featureToggle {
                            Text("\(featureToggle.label): " +
                                featureToggle.effectLine(enabled: toggles.isEnabled(featureToggle)))
                                .font(SampleTokens.Typography.caption)
                                .foregroundColor(SampleTokens.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    CountPill(count: specs.count)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityId(section.testId)
            if let featureToggle {
                Toggle(featureToggle.label, isOn: Binding(
                    get: { toggles.isEnabled(featureToggle) },
                    set: { set(featureToggle, $0) }))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: SampleTokens.Colors.accent))
                    .disabled(!toggles.isAvailable(featureToggle))
                    .accessibilityId(featureToggle.testId)
            }
            Button(action: onToggle) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .frame(width: SampleTokens.Size.icon, height: SampleTokens.Size.icon)
                    .frame(width: SampleTokens.Size.touchMin, height: SampleTokens.Size.touchMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // The 24 pt glyph keeps its place and the header its height: the full touch target spills into the
            // header's own padding (above, below and trailing) instead of growing the row.
            .padding(.vertical, -Self.chevronSlop)
            .padding(.trailing, -Self.chevronSlop)
            .accessibilityLabelCompat(isExpanded ? "Collapse" : "Expand")
            .accessibilityId("\(section.testId)-chevron")
        }
        .padding(.horizontal, SampleTokens.Spacing.space3)
        .padding(.vertical, 10)
        .frame(minHeight: SampleTokens.Size.touchMin)
        .background(
            RoundedRectangle(cornerRadius: SampleTokens.Radius.large, style: .continuous)
                .fill(SampleTokens.Colors.surface3.opacity(0.4)))
    }

    private func set(_ toggle: FeatureToggle, _ enabled: Bool) {
        switch toggle {
        case .pushRegistration:
            toggles.setPushRegistrationEnabled(enabled)
        case .forceLogin:
            Task { @MainActor in try? await toggles.setForceLogin(enabled) }
        }
    }
}

/// A scenario's card: title, two-line subtitle and the API it exercises, leading to its detail.
private struct ScenarioCard: View {
    let spec: ScenarioSpec
    let presenter: CommunityPresenter

    var body: some View {
        NavigationLink(destination: ScenarioDetailView(id: spec.id, presenter: presenter)) {
            VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
                Text(spec.title)
                    .font(SampleTokens.Typography.bodyStrong)
                    .foregroundColor(SampleTokens.Colors.text)
                    .multilineTextAlignment(.leading)
                Text(spec.subtitle)
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                ApiPill(name: spec.api)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SampleTokens.Spacing.space4)
            .padding(.vertical, SampleTokens.Spacing.space3)
            .background(
                RoundedRectangle(cornerRadius: SampleTokens.Radius.large, style: .continuous)
                    .fill(SampleTokens.Colors.surface))
            .overlay(
                RoundedRectangle(cornerRadius: SampleTokens.Radius.large, style: .continuous)
                    .strokeBorder(SampleTokens.Colors.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityId(spec.cardTestId)
    }
}
