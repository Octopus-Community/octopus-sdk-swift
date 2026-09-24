//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct MainRootFeedView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore

    @Compat.StateObject private var viewModel: MainRootFeedViewModel

    private let mainFlowPath: MainFlowPath
    private let navBarTitle: OctopusMainFeedTitle?
    private let coloredNavBar: Bool
    private let navBarLeadingAction: OctopusNavBarLeadingAction?

    @State private var zoomableImageInfo: ZoomableImageInfo?
    @State private var isScrollingDown = false
    /// Height of the floating "explore groups" bar, measured so the feed's first item can be inset
    /// below it (the bar floats over the content, so without this its top would sit under the bar).
    @State private var exploreBarHeight: CGFloat = 0

    init(octopus: OctopusSDK,
         mainFlowPath: MainFlowPath,
         navBarTitle: OctopusMainFeedTitle?,
         coloredNavBar: Bool,
         navBarLeadingAction: OctopusNavBarLeadingAction? = nil
    ) {
        _viewModel = Compat.StateObject(wrappedValue: MainRootFeedViewModel(octopus: octopus))
        self.mainFlowPath = mainFlowPath
        self.navBarTitle = navBarTitle
        self.coloredNavBar = coloredNavBar
        self.navBarLeadingAction = navBarLeadingAction
    }

    var body: some View {
        PostListView(octopus: viewModel.octopus, mainFlowPath: mainFlowPath, translationStore: translationStore,
                     selectedRootFeed: $viewModel.mainRootFeed,
                     zoomableImageInfo: $zoomableImageInfo,
                     isScrollingDown: $isScrollingDown,
                     rootFeedLoadFailure: viewModel.loadFailure,
                     retryRootFeedLoad: viewModel.retryFirstLoad,
                     // Inset the first item below the floating explore bar (+6pt gap matching the
                     // bar's own top gap, +8pt breathing room) so the first post's author is never
                     // hidden under the bar.
                     topContentInset: exploreBarHeight > 0 ? exploreBarHeight + 6 + 8 : 0)
            // Bar as an overlay (it floats over the feed, matching the design) rather than a
            // safe-area inset or a VStack: the scroll content inset never changes, so retracting
            // the bar does not fight the scroll momentum (no fling slow-down).
            .overlay(exploreGroupsBarOverlay, alignment: .top)
            // Value-driven animation so the bar's retract transition fires reliably (even on a
            // fast fling), mirroring the create button's own value-driven animation.
            .animation(.easeInOut(duration: 0.3), value: isScrollingDown)
            .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                    defaultLeadingBarItem: leadingBarItem,
                                    defaultLeadingSharedBackgroundVisibility: .hidden,
                                    defaultTrailingBarItem: trailingBarItem,
                                    defaultCenteredBarItem: centeredBarItem,
                                    defaultCenteredBarItemVisibility: centeredItemVisibility,
                                    navBarTitle: titleText,
                                    defaultNavigationBarPrimaryColor: coloredNavBar,
                                    // Glass (translucent) nav bar on the default (non-colored) feed,
                                    // matching the group/post detail screens. The colored case keeps
                                    // its solid primary background (public `mainFeedColoredNavBar` API).
                                    // `forceInlineTitle` keeps the title inline even though the feed is
                                    // a navigation root (glass uses `.automatic`, which would show a
                                    // large-title block here).
                                    defaultNavigationBarOpaque: false,
                                    forceInlineTitle: !coloredNavBar)
            .errorAlert(viewModel.$error)
    }

    @ViewBuilder
    private var exploreGroupsBarOverlay: some View {
        if !isScrollingDown {
            exploreGroupsBar
                .readHeight($exploreBarHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6) // 6pt gap below the navigation bar
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var exploreGroupsBar: some View {
        Button(action: { navigator.push(.groupList(context: .displayFeed)) }) {
            HStack(spacing: 3) {
                IconImage(theme.assets.icons.groups.openList)
                    .scaleEffect(1.2)
                Text("Groups.OpenList", bundle: .module)
                    .fontWeight(.medium)
            }
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.gray900)
        }
        // iOS 26: native glass button (correct bounds, no halo). Below: the existing outline pill.
        .modify {
#if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                $0.buttonStyle(.glass)
            } else {
                $0.buttonStyle(OctopusButtonStyle(.mid, style: .outline,
                                                  hasLeadingIcon: true, externalVerticalPadding: 5))
            }
#else
            $0.buttonStyle(OctopusButtonStyle(.mid, style: .outline,
                                              hasLeadingIcon: true, externalVerticalPadding: 5))
#endif
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var leadingBarItem: some View {
        if let navBarLeadingAction {
            // The host provided a leading item (close/back). It takes the leading slot; the feed title is
            // relocated to the centered slot (see `centeredBarItem`) so it is not lost.
            NavBarLeadingActionButton(navBarLeadingAction)
        } else if let navBarTitle, navBarTitle.placement == .leading {
            switch navBarTitle.content {
            case .logo:
                if theme.assets.logoIsCustomized {
                    Image(uiImage: theme.assets.logo)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 33)
                        .fixedSize()
                        .accessibilityHidden(true)
                } else {
                    defaultLeadingTitle
                }
            case let .text(title):
                Text(title.text)
                    .font(theme.fonts.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(coloredNavBar ? theme.colors.onPrimary : theme.colors.gray900)
                    .fixedSize()
            }
        } else if hasNoMeaningfulTitle {
            defaultLeadingTitle
        }
    }

    private var defaultLeadingTitle: some View {
        Text("Community.Default.Title", bundle: .module)
            .font(theme.fonts.title2)
            .fontWeight(.semibold)
            .foregroundColor(coloredNavBar ? theme.colors.onPrimary : theme.colors.gray900)
            .fixedSize()
    }

    /// True when `navBarTitle` doesn't resolve to any visible content —
    /// either because it's nil or because it requests a logo that hasn't been customized.
    private var hasNoMeaningfulTitle: Bool {
        guard let navBarTitle else { return true }
        if case .logo = navBarTitle.content, !theme.assets.logoIsCustomized {
            return true
        }
        return false
    }

    /// The feed title rendered in the centered slot when a host `navBarLeadingAction` occupies the leading
    /// slot. Mirrors the leading title resolution (logo if customized, else the provided text, else the
    /// default "Community") but with the inline nav-bar title styling used in the centered slot.
    @ViewBuilder
    private var relocatedCenteredTitle: some View {
        switch navBarTitle?.content {
        case .logo:
            if theme.assets.logoIsCustomized {
                Image(uiImage: theme.assets.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 33)
                    .fixedSize()
                    .accessibilityHidden(true)
            } else {
                defaultCenteredTitle
            }
        case let .text(title):
            Text(title.text)
                .inlineNavigationBarTitleFont()
                .foregroundColor(coloredNavBar ? theme.colors.onPrimary : theme.colors.gray900)
                .fixedSize()
        case nil:
            defaultCenteredTitle
        }
    }

    private var defaultCenteredTitle: some View {
        Text("Community.Default.Title", bundle: .module)
            .inlineNavigationBarTitleFont()
            .foregroundColor(coloredNavBar ? theme.colors.onPrimary : theme.colors.gray900)
            .fixedSize()
    }

    @ViewBuilder
    private var trailingBarItem: some View {
        if presentationMode.wrappedValue.isPresented {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Common.Close", bundle: .module)
                    .font(theme.fonts.navBarItem)
                    .foregroundColor(coloredNavBar ? theme.colors.onPrimary : theme.colors.primary)
            }
            .modify {
#if compiler(>=6.2)
                if #available(iOS 26.0, *), coloredNavBar {
                    $0.glassEffect(.regular.tint(theme.colors.primary))
                } else {
                    $0
                }
#else
                $0
#endif
            }
        }
    }

    @ViewBuilder
    private var centeredBarItem: some View {
        if navBarLeadingAction != nil {
            // The leading slot is taken by the host item, so the feed title is shown centered here.
            relocatedCenteredTitle
        } else if let navBarTitle, navBarTitle.placement == .center {
            switch navBarTitle.content {
            case .logo:
                if theme.assets.logoIsCustomized {
                    Image(uiImage: theme.assets.logo)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 33)
                        .fixedSize()
                        .accessibilityHidden(true)
                }
            case let .text(title):
                // This view is rendered inside `ToolbarItem(placement: .principal)`, which
                // does not inherit the system navigation bar title styling the way
                // `.navigationBarTitle(_:displayMode: .inline)` does. We therefore apply
                // `inlineNavigationBarTitleFont()` on each `Text` branch so the result
                // visually matches a native inline nav bar title. The helper reads the
                // font from `UINavigationBar.appearance()` so any host-app customization
                // is honored, falling back to the system default (`.headline`) otherwise.
                Text(title.text)
                    .inlineNavigationBarTitleFont()
                    .foregroundColor(coloredNavBar ? theme.colors.onPrimary : theme.colors.gray900)
                    .fixedSize()
            }
        }
    }

    private var centeredItemVisibility: Compat.Visibility {
        if navBarLeadingAction != nil {
            // Title relocated to center (see `relocatedCenteredTitle`): always resolves to visible content.
            return .visible
        } else if let navBarTitle, navBarTitle.placement == .center {
            switch navBarTitle.content {
            case .logo:
                if theme.assets.logoIsCustomized {
                    return .visible
                } else {
                    return .hidden
                }
            case .text:
                return .visible
            }
        } else {
            return .hidden
        }
    }

    private var titleText: Text {
        switch navBarTitle?.content {
        case let .text(title): Text(title.text)
        default: Text("Community.Default.Title", bundle: .module)
        }
    }
}
