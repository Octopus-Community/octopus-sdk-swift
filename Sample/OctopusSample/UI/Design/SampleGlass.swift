//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

// Every OS-version gate of the sample's visual layer lives in this file. iOS 26 APIs also sit behind
// `#if compiler(>=6.2)`, so the sample still builds with an Xcode 16 toolchain.
//
// The sample keeps its iOS 15 minimum, so each modern idiom (Liquid Glass, zoom transitions, symbol
// effects, sensory feedback, numeric content transitions) is wrapped here with its pre-iOS-26 (or pre-17/18)
// fallback: same structure, system materials instead of glass, no motion instead of new motion.
// Moving the sample to an iOS 26 minimum means deleting the `else` branches here, nowhere else.
//
// No custom glass surface exists yet: tab bar, navigation bars, toolbars and sheets get Liquid Glass from
// the system, and the one bar item that is not a control (the platform mark) opts out of it. When one is needed (a floating control drawn above content), its `glassEffect` and its
// material fallback go here.
//
// Motion rules: motion only confirms something the tester did or a value that changed, never decorates;
// with Reduce Motion on, zoom transitions and symbol bounces are skipped. Glass and materials are system
// ones, so Reduce Transparency and Increase Contrast are honoured by the OS.

extension View {
    /// Places a non-interactive mark in the leading bar slot. On iOS 26 the bar would wrap any item in a
    /// glass capsule, which makes it read as a button: the shared background is hidden there.
    @ViewBuilder
    func samplePlatformMark(@ViewBuilder _ makeMark: () -> some View) -> some View {
        let mark = makeMark()
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            toolbar {
                ToolbarItem(placement: .navigationBarLeading) { mark }
                    .sharedBackgroundVisibility(.hidden)
            }
        } else {
            toolbar { ToolbarItem(placement: .navigationBarLeading) { mark } }
        }
#else
        toolbar { ToolbarItem(placement: .navigationBarLeading) { mark } }
#endif
    }

    /// The tab bar keeps its full size while the tester scrolls, as on Android: the three tabs and their
    /// labels stay readable on every screen. `.never` is set explicitly because the iOS 26 default lets the
    /// system minimize it.
    @ViewBuilder
    func sampleTabBarNeverMinimize() -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.never)
        } else {
            self
        }
#else
        self
#endif
    }

    /// Marks the view a zoom transition starts from (iOS 18+).
    func sampleZoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        modifier(SampleZoomSourceModifier(id: AnyHashable(id), namespace: namespace))
    }

    /// Presents or pushes this view with a zoom from `sampleZoomSource(id:in:)` (iOS 18+, not with Reduce
    /// Motion, where the system default transition is kept).
    func sampleZoomTransition(sourceID: some Hashable, in namespace: Namespace.ID) -> some View {
        modifier(SampleZoomTransitionModifier(id: AnyHashable(sourceID), namespace: namespace))
    }

    /// One bounce of an SF Symbol when `value` changes (iOS 17+, not with Reduce Motion).
    func sampleSymbolBounce(value: some Equatable) -> some View {
        modifier(SampleSymbolBounceModifier(value: value))
    }

    /// Counts roll to their new value instead of being swapped (iOS 17+).
    @ViewBuilder
    func sampleNumericTransition(_ value: Int) -> some View {
        if #available(iOS 17.0, *) {
            contentTransition(.numericText(value: Double(value)))
                .animation(.default, value: value)
        } else {
            self
        }
    }

    /// A selection haptic when `trigger` changes (iOS 17+). Only for an action that moves the tester
    /// somewhere they did not tap directly, such as a row switching tabs.
    @ViewBuilder
    func sampleSelectionFeedback(trigger: some Equatable) -> some View {
        if #available(iOS 17.0, *) {
            sensoryFeedback(.selection, trigger: trigger)
        } else {
            self
        }
    }
}

private struct SampleZoomSourceModifier: ViewModifier {
    let id: AnyHashable
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

private struct SampleZoomTransitionModifier: ViewModifier {
    let id: AnyHashable
    let namespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

private struct SampleSymbolBounceModifier<Value: Equatable>: ViewModifier {
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *), !reduceMotion {
            content.symbolEffect(.bounce, value: value)
        } else {
            content
        }
    }
}
