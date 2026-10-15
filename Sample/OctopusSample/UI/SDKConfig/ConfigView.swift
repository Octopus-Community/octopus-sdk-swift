//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// Configuration, mirroring the Android sample's `ConfigScreen`: four sections, all collapsed, then the primary
/// action docked under the scroll. Shown on a first start ("Start SDK") and from Settings › Configuration
/// ("Apply"), in internal demo mode only.
struct ConfigView: View {
    let isRevisit: Bool

    @StateObjectCompat private var viewModel: ConfigViewModel
    @State private var expanded = Set<Section>()
    @State private var apiKeyVisible = false
    @State private var fieldsOpen = false
    @State private var showConfirm = false

    enum Section: String {
        case server, community, auth, theme, integration
    }

    init(isRevisit: Bool) {
        self.isRevisit = isRevisit
        _viewModel = StateObjectCompat(wrappedValue: ConfigViewModel(isRevisit: isRevisit))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
                section(.server, title: "Server environment") { serverContent }
                section(.community, title: "Community", summary: viewModel.communitySummary) { communityContent }
                section(.auth, title: "Connect your users (SSO)") { authContent }
                section(.theme, title: "Theme", contentSpacing: SampleTokens.Spacing.space2) { themeContent }
                integrationRow
                    .padding(.top, SampleTokens.Spacing.space2)
                debugContent
                    .padding(.top, SampleTokens.Spacing.space4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, SampleTokens.Spacing.space3)
        }
        .sampleScreenBackground()
        // On the scroll view only: set after the docked action, it would replace the button's own id.
        .accessibilityId("config-screen")
        .safeAreaInset(edge: .bottom, spacing: 0) { dockedAction }
        .navigationBarTitle("Configuration", displayMode: .inline)
        .alert("Non-default server", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("I understand, start") { viewModel.apply() }
        } message: {
            Text("You are about to connect the SDK to \(viewModel.confirmTarget). Client communities may be " +
                 "reachable.\n\nDO NOT publish any test content. Continue only for internal testing.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func section<Content: View>(_ id: Section, title: String, summary: String? = nil,
                                        contentSpacing: CGFloat = 0,
                                        @ViewBuilder content: () -> Content) -> some View {
        let isExpanded = expanded.contains(id)
        // Android's `ExpandableSection`: a divider, then the header row 8 above and below its bold title and
        // 24 pt chevron, held at the touch minimum (Apple asks 44 pt at least), then the content flush under it.
        // Android wraps each section's content in one Column, unspaced except Theme's (8), so the rows of a
        // choice sit edge to edge.
        return VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(SampleTokens.Colors.hairline).frame(height: 1)
            Button {
                toggle(id)
            } label: {
                HStack(spacing: SampleTokens.Spacing.space2) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                            .font(Font.subheadline.weight(.bold))
                            .foregroundColor(SampleTokens.Colors.accentText)
                        if let summary {
                            Text(summary)
                                .font(SampleTokens.Typography.caption)
                                .foregroundColor(SampleTokens.Colors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SampleTokens.Colors.accentText)
                        .frame(width: SampleTokens.Size.icon, height: SampleTokens.Size.icon)
                        .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
                }
                .padding(.vertical, SampleTokens.Spacing.space2)
                .frame(minHeight: SampleTokens.Size.touchMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityId("config-section-\(id.rawValue)")
            if isExpanded {
                VStack(alignment: .leading, spacing: contentSpacing) { content() }
            }
        }
    }

    private func toggle(_ id: Section) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
            if id == .server && viewModel.serverKind == .featureEnv && !viewModel.featureEnvsLoaded {
                viewModel.loadFeatureEnvs()
            }
        }
    }

    // MARK: Server environment

    @ViewBuilder
    private var serverContent: some View {
        hint("Keep the demo server unless a ticket says otherwise. Prod and custom hosts are for internal " +
             "testing — never publish test content on a client community.")
        RadioRow(label: "Demo server (default)", isSelected: viewModel.serverKind == .demo) {
            viewModel.setServerKind(.demo)
        }
        .accessibilityId("config-serverEnv-select")
        RadioRow(label: "Prod (api.8pus.io)", isSelected: viewModel.serverKind == .prod) {
            viewModel.setServerKind(.prod)
        }
        .accessibilityId("config-serverEnv-select")
        RadioRow(label: "Custom host", isSelected: viewModel.serverKind == .custom) {
            viewModel.setServerKind(.custom)
        }
        .accessibilityId("config-serverEnv-select")
        if viewModel.serverKind == .custom {
            ScenarioTextField(title: "Host", placeholder: "api-dev-xxx.8pus.io", text: $viewModel.customHost,
                              testId: "config-custom-host")
            ScenarioTextField(title: "Port", text: $viewModel.customPort, testId: "config-custom-port")
                .keyboardType(.numberPad)
        }
        if viewModel.showsFeatureEnvOption {
            RadioRow(label: "Feature env (one per ticket)", isSelected: viewModel.serverKind == .featureEnv) {
                viewModel.setServerKind(.featureEnv)
            }
            .accessibilityId("config-serverEnv-select")
        }
        if viewModel.serverKind == .featureEnv {
            featureEnvContent
                .padding(.leading, 32)
        }
        if !viewModel.isDefaultServer {
            HStack(alignment: .firstTextBaseline, spacing: SampleTokens.Spacing.space2) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Non-default server selected — client communities may be reachable. DO NOT publish any " +
                     "test content.")
                    .font(SampleTokens.Typography.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(SampleTokens.Colors.danger)
            .accessibilityId("config-non-default-warning")
        }
    }

    @ViewBuilder
    private var featureEnvContent: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
            if let selected = viewModel.selectedFeatureEnv {
                Text("Selected: \(selected.displayName) · \(selected.communityName)")
                    .font(SampleTokens.Typography.bodyStrong)
                    .foregroundColor(SampleTokens.Colors.text)
                hint(selected.apiHost)
            }
            if viewModel.featureEnvsLoading {
                hint("Loading live envs…")
            } else if let error = viewModel.featureEnvsError {
                Text(error)
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.danger)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Retry") { viewModel.loadFeatureEnvs() }
                    .foregroundColor(SampleTokens.Colors.accentText)
                    .frame(minHeight: SampleTokens.Size.touchMin)
            } else if viewModel.featureEnvs.isEmpty {
                hint(viewModel.featureEnvsLoaded ? "No live feature env right now." : "Loading live envs…")
            } else {
                ForEach(viewModel.featureEnvs) { env in
                    Text("\(env.displayName) — expires in \(env.expiresInDays()) d")
                        .font(SampleTokens.Typography.label)
                        .foregroundColor(SampleTokens.Colors.text)
                        .padding(.top, SampleTokens.Spacing.space1)
                    ForEach(env.usableCommunities) { community in
                        RadioRow(label: "\(env.name) · \(communityLabel(community))",
                                 isSelected: isSelected(env, community)) {
                            viewModel.selectFeatureEnv(env, community: community)
                        }
                    }
                }
            }
        }
    }

    private func communityLabel(_ community: FeatureEnv.Community) -> String {
        guard let description = community.description, !description.isEmpty else { return community.communityName }
        return "\(community.communityName) — \(description)"
    }

    private func isSelected(_ env: FeatureEnv, _ community: FeatureEnv.Community) -> Bool {
        guard let selected = viewModel.selectedFeatureEnv else { return false }
        return selected.envName == env.name && selected.communityId == community.communityId
            && selected.apiKey == community.apiKey
    }

    // MARK: Community

    @ViewBuilder
    private var communityContent: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
            hint("Pick the community to open. The preselected one fits most tests.")
            // The radio group only: around the key line below, the outer id would replace that line's own id.
            VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
                ForEach(AuthPreset.all) { preset in
                    RadioRow(label: preset.label,
                             isSelected: !viewModel.useCustomCommunity && preset.id == viewModel.resolvedPreset.id) {
                        viewModel.applyAuthPreset(preset)
                    }
                }
                RadioRow(label: "Custom… (paste any API key)", isSelected: viewModel.useCustomCommunity) {
                    viewModel.setUseCustomCommunity()
                }
            }
            .accessibilityId("config-apiKeySource-select")
            if !viewModel.useCustomCommunity {
                hint("Resolved key: \(ScenarioCatalog.maskApiKey(viewModel.resolvedPreset.key))")
                    .accessibilityId("config-resolved-key")
            } else {
                apiKeyField
            }
        }
    }

    private var apiKeyField: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
            Text("API Key")
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.textSecondary)
            HStack(spacing: SampleTokens.Spacing.space2) {
                Group {
                    if apiKeyVisible {
                        TextField("", text: $viewModel.customApiKey)
                    } else {
                        SecureField("", text: $viewModel.customApiKey)
                    }
                }
                .font(SampleTokens.Typography.body)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .accessibilityId("config-custom-api-key")
                Button {
                    apiKeyVisible.toggle()
                } label: {
                    Image(systemName: apiKeyVisible ? "eye.slash" : "eye")
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                        .frame(width: SampleTokens.Size.touchMin, height: SampleTokens.Size.touchMin)
                }
                .accessibilityLabel(apiKeyVisible ? "Hide API key" : "Show API key")
            }
            .padding(.leading, SampleTokens.Spacing.space3)
            .frame(minHeight: SampleTokens.Size.touchMin)
            .background(
                RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous)
                    .fill(SampleTokens.Colors.surface))
            .overlay(
                RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous)
                    .strokeBorder(SampleTokens.Colors.outline, lineWidth: 1))
        }
    }

    // MARK: Connect your users (SSO)

    @ViewBuilder
    private var authContent: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            ChipFlow(spacing: SampleTokens.Spacing.space2) {
                ForEach(viewModel.pickerUserIds, id: \.self) { id in
                    SampleChip(title: id, isSelected: viewModel.ssoUserId == id) { viewModel.ssoUserId = id }
                        .accessibilityId("config-sso-user-\(id)")
                }
            }
            if !viewModel.useCustomCommunity {
                hint("These settings pick the matching demo community above.")
            }
            // Read only: the switch lives on the Scenarios section header. The value still picks the key.
            let forceLogin = viewModel.forceLogin
            Text("\(FeatureToggle.forceLogin.label) — " +
                 FeatureToggle.forceLogin.readOnlyValueLine(enabled: forceLogin))
                .font(SampleTokens.Typography.body)
                .foregroundColor(SampleTokens.Colors.text)
            hint(FeatureToggle.forceLogin.effectLine(enabled: forceLogin))
            unifiedProfile
        }
    }

    @ViewBuilder
    private var unifiedProfile: some View {
        Text("Unified profile: " + (viewModel.unifiedProfile.isSwitchOn
                                    ? "On — host profile navigation" : "Off — native Octopus profiles"))
            .font(SampleTokens.Typography.body)
            .foregroundColor(SampleTokens.Colors.text)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityId("config-unified-profile-status")
        if isRevisit {
            SecondaryPillButton(title: "Open Unified Profile scenario", testId: "config-open-unified-profile") {
                SampleTabRouter.instance.select(.scenarios)
            }
        } else {
            hint("Start the SDK to try the Unified Profile scenario.")
        }
        hint(viewModel.unifiedProfileCommunityLine)
            .accessibilityId("config-unified-profile-community")
        if !viewModel.managedFields.isEmpty {
            Button {
                fieldsOpen.toggle()
            } label: {
                HStack(spacing: SampleTokens.Spacing.space2) {
                    Text("Fields the app owns")
                        .font(SampleTokens.Typography.bodyStrong)
                        .foregroundColor(SampleTokens.Colors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(viewModel.managedFields.count) of \(SDKConfig.ProfileField.allCases.count)")
                        .font(SampleTokens.Typography.body)
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                    Image(systemName: fieldsOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                }
                .frame(minHeight: SampleTokens.Size.touchMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(fieldsOpen ? "Expanded" : "Collapsed")
            .accessibilityId("config-unified-profile-detail")
            if fieldsOpen {
                ForEach(SDKConfig.ProfileField.allCases, id: \.self) { field in
                    CheckboxRow(title: field.title, subtitle: field.apiName,
                                isChecked: viewModel.managedFields.contains(field)) {
                        viewModel.toggleManagedField(field)
                    }
                }
            }
        }
    }

    // MARK: Theme

    private var themeContent: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            Picker("Appearance", selection: $viewModel.appearance) {
                ForEach(SampleAppearance.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityId("config-appearance-select")
            Picker("Theme preset", selection: $viewModel.themePreset) {
                ForEach(SDKThemePreset.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityId("config-theme-preset-select")
            hint("\"SDK default\" hands the SDK no theme — what a fresh integration looks like.")
        }
    }

    // MARK: Host app integration

    @ViewBuilder
    private var integrationRow: some View {
        if isRevisit {
            NavigationLink(destination: DeveloperToolsView()) { integrationLabel(showsChevron: true) }
                .buttonStyle(.plain)
                .accessibilityId("config-section-integration")
        } else {
            // Before the SDK exists, Developer tools has nothing to act on: the row only says where it went.
            integrationLabel(showsChevron: false)
                .accessibilityId("config-section-integration")
        }
    }

    private func integrationLabel(showsChevron: Bool) -> some View {
        HStack(spacing: SampleTokens.Spacing.space3) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18))
                .foregroundColor(SampleTokens.Colors.accentText)
                .frame(width: SampleTokens.Size.icon)
            VStack(alignment: .leading, spacing: 2) {
                Text("Host app integration")
                    .font(SampleTokens.Typography.bodyStrong)
                    .foregroundColor(SampleTokens.Colors.text)
                Text("Profile, sign-in, links: now in Settings › Developer tools")
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SampleTokens.Colors.textSecondary)
            }
        }
        .padding(SampleTokens.Spacing.space3)
        .frame(minHeight: SampleTokens.Size.rowMin)
        .sampleCardSurface()
        .contentShape(Rectangle())
    }

    // MARK: Debug (iOS only)

    private var debugContent: some View {
        Toggle(isOn: Binding(get: { viewModel.forceOffline }, set: { viewModel.setForceOffline($0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Act as if offline")
                    .font(SampleTokens.Typography.bodyStrong)
                    .foregroundColor(SampleTokens.Colors.text)
                hint("The SDK behaves as with no network. Applied at once.")
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: SampleTokens.Colors.accent))
        .accessibilityId("qa-config-forceOffline")
    }

    // MARK: Docked action

    private var dockedAction: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            if let blocker = viewModel.applyBlocker {
                Text(blocker)
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityId("config-apply-blocker")
            } else if let outcome = viewModel.outcome {
                Text(outcome)
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityId("config-apply-outcome")
            }
            PrimaryPillButton(title: isRevisit ? "Apply" : "Start SDK",
                              systemImage: isRevisit ? nil : "play.fill",
                              isEnabled: viewModel.applyBlocker == nil,
                              testId: "config-start-button") {
                if viewModel.isDefaultServer {
                    viewModel.apply()
                } else {
                    showConfirm = true
                }
            }
        }
        .padding(.horizontal, SampleTokens.Spacing.space4)
        .padding(.vertical, SampleTokens.Spacing.space3)
        .background(SampleTokens.Colors.surface.edgesIgnoringSafeArea(.bottom))
        .overlay(Rectangle().fill(SampleTokens.Colors.hairline).frame(height: 1), alignment: .top)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(SampleTokens.Typography.caption)
            .foregroundColor(SampleTokens.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension SDKConfig.ProfileField {
    var title: String {
        switch self {
        case .nickname: "Nickname"
        case .bio: "Bio"
        case .picture: "Profile picture"
        }
    }

    /// The SDK's name for the field, as the Android sample shows it under the title.
    var apiName: String {
        switch self {
        case .nickname: "nickname"
        case .bio: "bio"
        case .picture: "picture"
        }
    }
}

private struct RadioRow: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Android's Config `RadioRow`: the radio keeps its 48 pt box, the label starts right after it.
            HStack(spacing: 0) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? SampleTokens.Colors.accentText : SampleTokens.Colors.textSecondary)
                    .frame(width: SampleTokens.Size.touchMin, height: SampleTokens.Size.touchMin)
                Text(label)
                    .font(SampleTokens.Typography.callout)
                    .foregroundColor(SampleTokens.Colors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: SampleTokens.Size.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct CheckboxRow: View {
    let title: String
    let subtitle: String
    let isChecked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SampleTokens.Spacing.space3) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(isChecked ? SampleTokens.Colors.accentText : SampleTokens.Colors.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SampleTokens.Typography.body)
                        .foregroundColor(SampleTokens.Colors.text)
                    Text(subtitle)
                        .font(SampleTokens.Typography.caption)
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: SampleTokens.Size.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? [.isSelected] : [])
    }
}

/// A selectable chip, the iOS twin of the Android sample's filter chip: a check and the accent container when on.
struct SampleChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SampleTokens.Spacing.space1) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(SampleTokens.Typography.label)
            }
            .foregroundColor(isSelected ? SampleTokens.Colors.accentText : SampleTokens.Colors.text)
            .padding(.horizontal, SampleTokens.Spacing.space3)
            .frame(minHeight: SampleTokens.Size.chipHeight)
            .background(
                RoundedRectangle(cornerRadius: SampleTokens.Radius.small, style: .continuous)
                    .fill(isSelected ? SampleTokens.Colors.accentContainer : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: SampleTokens.Radius.small, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : SampleTokens.Colors.outline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Chips that wrap onto the next line, like Android's `FlowRow`. iOS 15 has no `Layout`, so it stacks them.
struct ChipFlow<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            FlowLayout(spacing: spacing) { content() }
        } else {
            VStack(alignment: .leading, spacing: spacing) { content() }
        }
    }
}

@available(iOS 16.0, *)
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let added = rows[rows.count - 1].indices.isEmpty ? size.width
                : rows[rows.count - 1].width + spacing + size.width
            if added > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row(indices: [index], width: size.width, height: size.height))
            } else {
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width = added
                rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            }
        }
        return rows
    }
}
