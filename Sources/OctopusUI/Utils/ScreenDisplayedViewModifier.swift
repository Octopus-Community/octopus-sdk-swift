//
//  Copyright © 2026 Octopus Community. All rights reserved.
//


//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import OctopusCore

struct ScreenDisplayedViewModifier: ViewModifier {
    let screen: SdkEvent.ScreenDisplayedContext
    let trackingApi: TrackingApi

    func body(content: Content) -> some View {
        content
            .onFirstAppear {
                trackingApi.emit(event: .screenDisplayed(screen))
            }
    }
}

extension View {
    func emitScreenDisplayed(_ screen: SdkEvent.ScreenDisplayedContext, trackingApi: TrackingApi) -> some View {
        self.modifier(ScreenDisplayedViewModifier(screen: screen, trackingApi: trackingApi))
    }
}
