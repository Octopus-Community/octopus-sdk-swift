//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

/// Top-right overflow menu of the connected user's own screens — the Activity screen (Unified
/// Profile) and the legacy profile summary (whose "…" used to push a separate
/// "Community settings" screen; it now opens this same menu — PO feedback, 2026-07-17). Organised
/// in four visually-separated blocks (mirrors Android's `ActivityOverflowMenu` and the Figma menu
/// design, node 17130-844):
/// 1. profile actions — Unified Profile "View my profile" / "Edit my profile" (each shown only when
///    its host target is reachable), or the legacy "My profile" account settings row;
/// 2. community legal links (terms / privacy / guidelines), reusing the same URLs as the report
///    explanation screen;
/// 3. content reporting ("Report inappropriate content");
/// 4. logout (legacy profile with an Octopus-owned account only).
///
/// Modeled on `PostMoreMenuButton`: an iOS 14+ `Menu` with a `.highPriorityGesture` tap-absorption
/// workaround, and an iOS 13 action-sheet fallback. Every row (profile actions, legal links, report,
/// logout) is a `Button` — the proven primitive for a system `Menu`/`ActionSheet` row (a `Link`
/// wrapped in a custom view is not a verified `Menu` primitive). Row icons are the exact Figma menu
/// vectors (node 17130-844), shipped as template PDF assets in the module bundle (`activityMenu*`)
/// so they render identically to the Android drawables and follow the system menu tint — the
/// earlier SF-symbol approximations diverged from the design (pencil especially). Logout is the one
/// exception: it is a legacy-only row absent from the Figma menu, so it keeps its SF Symbol.
/// Legal links open through the environment `urlOpener`, so the host's `onNavigateToURL` callback is
/// honored (same routing as `RichText`).
struct ActivityOverflowMenuButton: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.urlOpener) private var urlOpener

    /// "View my profile" — shown only when Unified Profile is active AND the connected user has a
    /// reachable host profile (non-guest with a client id).
    let showViewProfile: Bool
    /// "Edit my profile" — shown only when `showViewProfile` AND the host wired the edit callback, so
    /// the item never dead-ends.
    let showEditProfile: Bool
    let onViewProfile: () -> Void
    let onEditProfile: () -> Void
    let communityGuidelinesUrl: URL
    let privacyPolicyUrl: URL
    let termsOfUseUrl: URL
    let onReportContent: () -> Void
    /// "My profile" account settings — legacy profile summary with an Octopus-owned account only
    /// (an SSO profile is managed by the host app).
    let showAccountSettings: Bool
    let onAccountSettings: () -> Void
    /// "Log out" — legacy profile summary with an Octopus-owned account only.
    let showLogout: Bool
    let onLogout: () -> Void

    init(showViewProfile: Bool,
         showEditProfile: Bool,
         onViewProfile: @escaping () -> Void,
         onEditProfile: @escaping () -> Void,
         communityGuidelinesUrl: URL,
         privacyPolicyUrl: URL,
         termsOfUseUrl: URL,
         onReportContent: @escaping () -> Void,
         showAccountSettings: Bool = false,
         onAccountSettings: @escaping () -> Void = {},
         showLogout: Bool = false,
         onLogout: @escaping () -> Void = {}) {
        self.showViewProfile = showViewProfile
        self.showEditProfile = showEditProfile
        self.onViewProfile = onViewProfile
        self.onEditProfile = onEditProfile
        self.communityGuidelinesUrl = communityGuidelinesUrl
        self.privacyPolicyUrl = privacyPolicyUrl
        self.termsOfUseUrl = termsOfUseUrl
        self.onReportContent = onReportContent
        self.showAccountSettings = showAccountSettings
        self.onAccountSettings = onAccountSettings
        self.showLogout = showLogout
        self.onLogout = onLogout
    }

    @State private var iOS13ActionSheetIsPresented = false

    @Compat.ScaledMetric(relativeTo: .subheadline) private var iconSize: CGFloat = 24

    var body: some View {
        if #available(iOS 14.0, *) {
            Menu(content: {
                // Block 1 — profile actions (each shown only when its target is reachable)
                if showViewProfile {
                    Button(action: onViewProfile) {
                        Label(title: { Text("Menu.ViewProfile", bundle: .module) },
                              icon: { Self.menuIcon("activityMenuViewProfile") })
                    }
                }
                if showEditProfile {
                    Button(action: onEditProfile) {
                        Label(title: { Text("Menu.EditProfile", bundle: .module) },
                              icon: { Self.menuIcon("activityMenuEditProfile") })
                    }
                }
                if showAccountSettings {
                    Button(action: onAccountSettings) {
                        Label(title: { Text("Settings.Profile", bundle: .module) },
                              icon: { Self.menuIcon("activityMenuViewProfile") })
                    }
                }
                if showViewProfile || showEditProfile || showAccountSettings {
                    Divider()
                }

                // Block 2 — community legal links, in the design's order (terms, privacy,
                // guidelines). Button rows (a Link wrapped in a custom view is not a verified Menu
                // row) routed through urlOpener so onNavigateToURL is honored.
                Button(action: { urlOpener.open(url: termsOfUseUrl) }) {
                    Label(title: { Text("Settings.TermsOfUse", bundle: .module) },
                          icon: { Self.menuIcon("activityMenuTermsOfUse") })
                }
                Button(action: { urlOpener.open(url: privacyPolicyUrl) }) {
                    Label(title: { Text("Settings.PrivacyPolicy", bundle: .module) },
                          icon: { Self.menuIcon("activityMenuPrivacyPolicy") })
                }
                Button(action: { urlOpener.open(url: communityGuidelinesUrl) }) {
                    Label(title: { Text("Settings.CommunityGuidelines", bundle: .module) },
                          icon: { Self.menuIcon("activityMenuCommunityGuidelines") })
                }

                Divider()

                // Block 3 — report
                Button(action: onReportContent) {
                    Label(title: { Text("Settings.ReportContent", bundle: .module) },
                          icon: { Self.menuIcon("activityMenuReportContent") })
                }

                // Block 4 — logout (destructive, legacy Octopus-owned profile only)
                if showLogout {
                    Divider()
                    if #available(iOS 15.0, *) {
                        Button(role: .destructive, action: onLogout) {
                            Label(title: { Text("Settings.LogOut.Button", bundle: .module) },
                                  icon: { Image(systemName: "rectangle.portrait.and.arrow.right") })
                        }
                    } else {
                        Button(action: onLogout) {
                            Text("Settings.LogOut.Button", bundle: .module)
                        }
                    }
                }
            }, label: {
                menuLabel
            })
            .modify {
                // Below iOS 26, `.plain` keeps the bare icon look; on iOS 26 the default style lets
                // the toolbar give the button the same circular glass background as the profile
                // screens' nav-bar buttons (PO feedback, 2026-07-17).
                if #unavailable(iOS 26.0) {
                    $0.buttonStyle(.plain)
                } else { $0 }
            }
            // Same tap-absorption workaround as `PostMoreMenuButton` for iOS 16 and earlier.
            .highPriorityGesture(TapGesture().onEnded {})
        } else {
            Button(action: { iOS13ActionSheetIsPresented = true }) {
                menuLabel
            }
            .buttonStyle(.plain)
            .actionSheet(isPresented: $iOS13ActionSheetIsPresented) { actionSheet }
        }
    }

    /// A menu-row icon exported from the Figma menu design (node 17130-844) and bundled as a template
    /// PDF (`activityMenu*` in the module asset catalog). Template rendering makes it follow the
    /// system menu tint, exactly like the SF Symbols it replaced.
    private static func menuIcon(_ name: String) -> Image {
        Image(name, bundle: .module).renderingMode(.template)
    }

    private var actionSheet: ActionSheet {
        var buttons: [ActionSheet.Button] = []
        if showViewProfile {
            buttons.append(.default(Text("Menu.ViewProfile", bundle: .module), action: onViewProfile))
        }
        if showEditProfile {
            buttons.append(.default(Text("Menu.EditProfile", bundle: .module), action: onEditProfile))
        }
        if showAccountSettings {
            buttons.append(.default(Text("Settings.Profile", bundle: .module), action: onAccountSettings))
        }
        buttons.append(.default(Text("Settings.TermsOfUse", bundle: .module),
                                action: { urlOpener.open(url: termsOfUseUrl) }))
        buttons.append(.default(Text("Settings.PrivacyPolicy", bundle: .module),
                                action: { urlOpener.open(url: privacyPolicyUrl) }))
        buttons.append(.default(Text("Settings.CommunityGuidelines", bundle: .module),
                                action: { urlOpener.open(url: communityGuidelinesUrl) }))
        buttons.append(.default(Text("Settings.ReportContent", bundle: .module), action: onReportContent))
        if showLogout {
            buttons.append(.destructive(Text("Settings.LogOut.Button", bundle: .module), action: onLogout))
        }
        buttons.append(.cancel())
        return ActionSheet(title: Text("Activity.Screen.Title", bundle: .module), buttons: buttons)
    }

    /// The nav-bar label. On iOS 26 the `Label` inside a toolbar gets the system circular glass
    /// background (same treatment as the profile screens' nav-bar buttons — PO feedback,
    /// 2026-07-17); below, the plain sized icon keeps the legacy look.
    @ViewBuilder
    private var menuLabel: some View {
        if #available(iOS 26.0, *) {
            Label(title: { Text("Accessibility.Common.More", bundle: .module) },
                  icon: { Image(uiImage: theme.assets.icons.common.moreActions) })
                .accessibilityLabelInBundle("Accessibility.Common.More")
        } else {
            Image(uiImage: theme.assets.icons.common.moreActions)
                .resizable()
                .scaledToFit()
                .frame(width: max(iconSize, 24), height: max(iconSize, 24))
                .foregroundColor(theme.colors.gray900)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabelInBundle("Accessibility.Common.More")
        }
    }
}
