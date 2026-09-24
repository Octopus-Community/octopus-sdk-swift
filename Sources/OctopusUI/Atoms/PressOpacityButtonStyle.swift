//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// `ButtonStyle` that dims the label to 60% opacity while pressed. Shared: the reaction
/// button and the who-reacted rows both show touch-down feedback this way without resorting to a raw `DragGesture` that would
/// steal the enclosing `ScrollView`'s swipe — `ButtonStyle`'s `isPressed` is what SwiftUI
/// uses internally for exactly this scroll-cooperation.
struct PressOpacityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}
