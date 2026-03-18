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

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    private let mainFlowPath: MainFlowPath
    private let navBarTitle: OctopusMainFeedTitle?
    private let coloredNavBar: Bool

    @State private var zoomableImageInfo: ZoomableImageInfo?

    init(octopus: OctopusSDK,
         mainFlowPath: MainFlowPath,
         navBarTitle: OctopusMainFeedTitle?,
         coloredNavBar: Bool,
    ) {
        _viewModel = Compat.StateObject(wrappedValue: MainRootFeedViewModel(octopus: octopus))
        self.mainFlowPath = mainFlowPath
        self.navBarTitle = navBarTitle
        self.coloredNavBar = coloredNavBar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

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
            .buttonStyle(OctopusButtonStyle(.mid, style: .outline, hasLeadingIcon: true, externalVerticalPadding: 5))
            .padding(.horizontal, 16)
            PostListView(octopus: viewModel.octopus, mainFlowPath: mainFlowPath, translationStore: translationStore,
                         selectedRootFeed: $viewModel.mainRootFeed,
                         zoomableImageInfo: $zoomableImageInfo)
        }
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem,
                                defaultCenteredBarItem: title,
                                defaultCenteredBarItemVisibility: titleVisibility,
                                navBarTitle: titleText,
                                defaultNavigationBarPrimaryColor: coloredNavBar)
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

    @ViewBuilder
    private var leadingBarItem: some View {
        if let navBarTitle, navBarTitle.placement == .leading {
            switch navBarTitle.content {
            case .logo:
                if theme.assets.logoIsCustomized {
                    Image(uiImage: theme.assets.logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 33)
                        .fixedSize()
                        .accessibilityHidden(true)
                }
            case let .text(title):
                Text(title.text)
                    .font(theme.fonts.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(coloredNavBar ? theme.colors.onPrimary : theme.colors.gray900)
                    .fixedSize()
            }
        }
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
    private var title: some View {
        if let navBarTitle, navBarTitle.placement == .center {
            switch navBarTitle.content {
            case .logo:
                if theme.assets.logoIsCustomized {
                    Image(uiImage: theme.assets.logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 33)
                        .fixedSize()
                        .accessibilityHidden(true)
                } else {
                    Text("Community.Default.Title", bundle: .module)
                }
            case let .text(title):
                Text(title.text)
                    .font(theme.fonts.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(coloredNavBar ? theme.colors.onPrimary : theme.colors.gray900)
                    .fixedSize()
            }
        } else {
            Text("Community.Default.Title", bundle: .module)
        }
    }

    private var titleVisibility: Compat.Visibility {
        if let navBarTitle, navBarTitle.placement == .center {
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
