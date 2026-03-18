//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct GroupListScreen: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) var presentationMode

    let octopus: OctopusSDK
    let context: GroupListContext

    var body: some View {
        NavigationView {
            GroupListView(octopus: octopus, context: context)
                .toolbar(leading: closeButton, trailing: EmptyView())
        }
    }

    var closeButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            IconImage(theme.assets.icons.common.close)
                .font(theme.fonts.navBarItem)
                .contentShape(Rectangle())
                .accessibilityLabelInBundle("Common.Close")
                .accentColor(theme.colors.primary)
        }
    }
}

struct GroupListView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @EnvironmentObject var trackingApi: TrackingApi

    @Compat.StateObject private var viewModel: GroupListViewModel

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    init(octopus: OctopusSDK, context: GroupListContext) {
        _viewModel = Compat.StateObject(wrappedValue: GroupListViewModel(octopus: octopus, context: context))
    }

    var body: some View {
        ContentView(
            context: viewModel.context,
            groups: viewModel.groups,
            canChangeFollowStatusByGroupId: viewModel.canChangeFollowStatusByGroupId,
            isFollowedByGroupId: viewModel.isFollowedByGroupId,
            refresh: viewModel.refresh,
            selectGroup: {
                switch viewModel.context {
                case let .groupSelection(_, setSelectedGroup):
                    setSelectedGroup($0.id)
                case .displayFeed:
                    navigator.push(.groupDetail(topic: $0.coreTopic))
                }
            },
            changeFollowStatus: viewModel.changeFollowStatus(groupId:follow:),
        )
        .navigationBarTitle(Text(navBarTitleKey, bundle: .module), displayMode: .inline)
        .toastContainer(octopus: viewModel.octopus)
        .modify {
            switch viewModel.context {
            case .displayFeed:
                $0.emitScreenDisplayed(.groups, trackingApi: trackingApi)
            case .groupSelection:
                $0
            }
        }
        .onAppear {
            viewModel.recomputeSections()
        }
        .compatAlert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
        .onReceive(viewModel.$error) { error in
            guard let error else { return }
            displayableError = error
            displayError = true
        }
    }

    var navBarTitleKey: LocalizedStringKey {
        switch viewModel.context {
        case .displayFeed:      "Groups.Title.List"
        case .groupSelection:   "Groups.Title.Selection"
        }
    }
}

private struct ContentView: View {
    let context: GroupListContext
    let groups: GroupList?
    let canChangeFollowStatusByGroupId: [String: Bool]
    let isFollowedByGroupId: [String: Bool]

    let refresh: @Sendable () async -> Void
    let selectGroup: (GroupList.Group) -> Void
    let changeFollowStatus: (String, Bool) -> Void

    @State private var selectedGroupId: String?

    private let leadingPadding: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
#if compiler(>=6.2)
            // Disable nav bar opacity on iOS 26 to have the same behavior as before.
            // TODO: See with product team if we need to keep it.
            if #available(iOS 26.0, *) {
                Color.white.opacity(0.0001)
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
#endif
            Compat.ScrollView(refreshAction: refresh) {
                VStack(alignment: .leading, spacing: 0) {
                    if let groups {
                        ForEach(groups.sections.indices, id: \.self) { sectionIdx in
                            let section = groups.sections[sectionIdx]
                            if let currentSectionGroups = groups.groupsBySection[section], !currentSectionGroups.isEmpty {
                                SectionView(section: section, horizontalPadding: leadingPadding)

                                ForEach(currentSectionGroups.indices, id: \.self) { groupIdx in
                                    let group = currentSectionGroups[groupIdx]
                                    GroupView(
                                        context: context,
                                        group: group,
                                        canChangeFollowStatus: canChangeFollowStatusByGroupId[group.id] ?? false,
                                        isFollowed: isFollowedByGroupId[group.id] ?? false,
                                        leadingPadding: leadingPadding,
                                        selectedGroupId: $selectedGroupId,
                                        selectGroup: selectGroup,
                                        changeFollowStatus: changeFollowStatus
                                    )
                                }
                            }
                        }

                        PoweredByOctopusView()
                            .padding(.top, 20)
                            .padding(.bottom, 60)
                    } else {
                        Compat.ProgressView()
                            .frame(width: 100)
                            .padding(.top, 20)
                    }
                }
            }
            .onValueChanged(of: context, initial: true) { context in
                switch context {
                case let .groupSelection(selectedGroupId, _):
                    self.selectedGroupId = selectedGroupId
                default: break
                }
            }
        }
    }
}

private struct SectionView: View {
    @Environment(\.octopusTheme) private var theme

    let section: GroupList.Section
    let horizontalPadding: CGFloat

    var body: some View {
        section.displayableString.textView
            .font(theme.fonts.body2)
            .fontWeight(.semibold)
            .foregroundColor(theme.colors.gray500)
            .padding(.top, 24)
            .padding(.bottom, 4)
            .padding(.horizontal, horizontalPadding)
    }
}

private struct GroupView: View {
    @Environment(\.octopusTheme) private var theme

    let context: GroupListContext
    let group: GroupList.Group
    let canChangeFollowStatus: Bool
    let isFollowed: Bool
    let leadingPadding: CGFloat

    @Binding var selectedGroupId: String?

    let selectGroup: (GroupList.Group) -> Void
    let changeFollowStatus: (String, Bool) -> Void

    var body: some View {
        Button(action: {
            switch context {
            case .displayFeed:
                selectGroup(group)
            case .groupSelection:
                selectedGroupId = group.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectGroup(group)
                }
            }
        }) {
            HStack(spacing: 12) {
                Text(group.name)
                    .font(theme.fonts.body1)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.gray900)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                switch context {
                case .displayFeed:
                    FollowGroupButton(canChangeFollowStatus: canChangeFollowStatus, isFollowed: isFollowed,
                                      toggleFollow: { changeFollowStatus(group.id, !isFollowed) })

                    IconImage(theme.assets.icons.common.listCellNavIndicator)
                        .font(theme.fonts.body1)
                        .foregroundColor(theme.colors.gray300)
                case .groupSelection:
                    IconImage(theme.assets.icons.groups.selected)
                        .font(theme.fonts.body1)
                        .foregroundColor(theme.colors.primary)
                        .opacity(group.id == selectedGroupId ? 1 : 0)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, verticalPadding)
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
        }
        .buttonStyle(CellStyle())
    }

    var trailingPadding: CGFloat {
        switch context {
        case .displayFeed: 9
        case .groupSelection: 12
        }
    }

    var verticalPadding: CGFloat {
        switch context {
        case .displayFeed: canChangeFollowStatus ? 7 : 14
        case .groupSelection: 14
        }
    }
}

private struct CellStyle: ButtonStyle {
    @Environment(\.octopusTheme) private var theme

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? theme.colors.gray200 : .clear)
    }
}

extension GroupList.Section {
    var displayableString: DisplayableString {
        switch self {
        case .followedGroups: .localizationKey("Groups.Section.Followed")
        case .otherGroups: .localizationKey("Groups.Section.OtherGroups")
        case let .clientSection(name): .localizedString(name)
        }
    }
}
