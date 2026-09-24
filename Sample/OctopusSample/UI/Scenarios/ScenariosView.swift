//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct ScenariosView: View {
    let showFullScreen: (@escaping () -> any View) -> Void
    let showInSheet: (@escaping () -> any View) -> Void

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Presentation")) {
                    SheetCell(showInSheet: showInSheet)
                    CustomThemeCell(showFullScreen: showFullScreen)
                    InitialScreenCell()
                }
                Section(header: Text("Notifications")) {
                    NotSeenNotificationsCell(showFullScreen: showFullScreen)
                    PushTokenCell()
                }
                Section(header: Text("Groups")) {
                    SyncFollowGroupsCell()
                    GroupSectionsCell()
                }
                Section(header: Text("A/B Testing")) {
                    TrackABTestsCell(showFullScreen: showFullScreen)
                    ForceOctopusABTestsCell(showFullScreen: showFullScreen)
                }
                Section(header: Text("Bridge")) {
                    BridgeToClientObjectCell(showFullScreen: showFullScreen)
                }
                Section(header: Text("Profile")) {
                    ProfileFieldsLockCell()
                    UnifiedProfileCell()
                    ProfileDirectOpenCell()
                    CommunityDataCell()
                }
                Section(header: Text("Content")) {
                    ContentOptionsCell()
                    ScreenStatesCell()
                }
                Section(header: Text("Consent")) {
                    TermsAcceptanceModeCell()
                }
                Section(header: Text("Analytics")) {
                    CustomEventsCell()
                    EventsCell()
                }
                Section(header: Text("Configuration")) {
                    SwitchCommunityCell(showFullScreen: showFullScreen)
                    LanguageCell()
                    // Internal only: needs the directory secrets AND internal demo mode. Outside demo mode
                    // the SDK is built by the hardcoded `initializeSdkInSSO…` path and no `SDKConfig` is
                    // ever stored, so applying an env would abort on `fatalError("SDK config should be
                    // set…")` — the same guard `SwitchCommunityViewModel` already applies.
                    if DefaultValuesProvider.internalDemoMode && DefaultValuesProvider.featureEnvsConfigured {
                        FeatureEnvsCell()
                    }
                }
            }
            .listStyle(.grouped)
            .navigationBarTitle(Text("Scenarios"), displayMode: .inline)
            .hostAppFooter()
        }
    }
}
