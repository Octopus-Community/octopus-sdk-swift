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
                }
                Section(header: Text("Groups")) {
                    SyncFollowGroupsCell()
                }
                Section(header: Text("A/B Testing")) {
                    TrackABTestsCell(showFullScreen: showFullScreen)
                    ForceOctopusABTestsCell(showFullScreen: showFullScreen)
                }
                Section(header: Text("Bridge")) {
                    BridgeToClientObjectCell(showFullScreen: showFullScreen)
                }
                Section(header: Text("Analytics")) {
                    CustomEventsCell()
                    EventsCell()
                }
                Section(header: Text("Configuration")) {
                    SwitchCommunityCell(showFullScreen: showFullScreen)
                    LanguageCell()
                }
            }
            .listStyle(.grouped)
            .navigationBarTitle(Text("Scenarios"), displayMode: .inline)
        }
    }
}
