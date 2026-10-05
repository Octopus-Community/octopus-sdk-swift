//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// The environment objects that the SDK's entry screens (`OctopusHomeScreen`, `OctopusProfileScreen`) provide to
/// every screen below them.
///
/// What the SDK presents (sheets, full screen covers, popovers) is handed them again, explicitly, by the
/// `octopus…` presentation modifiers below, instead of counting on SwiftUI to pass the presenter's environment
/// down. SwiftUI does pass it on iPhone and iPad, but when an iPad app runs on a Mac it evaluates the presented
/// content once before doing so: any `@EnvironmentObject` read at that point traps with "No ObservableObject of
/// type … found".
struct SharedEnvironmentObjects {
    let translationStore: ContentTranslationPreferenceStore
    let gamificationRulesViewManager: GamificationRulesViewManager
    let displayConfigManager: DisplayConfigManager
    let reactionsListManager: ReactionsListManager
    let videoManager: VideoManager
    let languageManager: LanguageManager
}

private struct SharedEnvironmentObjectsKey: EnvironmentKey {
    /// Computed rather than stored: not all the objects are `Sendable`, so they cannot sit in a static constant.
    static var defaultValue: SharedEnvironmentObjects? { nil }
}

extension EnvironmentValues {
    /// The objects injected above by `sharedEnvironmentObjects(_:)`, for a presentation to hand them to the content
    /// it presents. `nil` outside of the SDK's entry screens, in previews for instance.
    var sharedEnvironmentObjects: SharedEnvironmentObjects? {
        get { self[SharedEnvironmentObjectsKey.self] }
        set { self[SharedEnvironmentObjectsKey.self] = newValue }
    }
}

extension View {
    /// Injects `objects` as environment objects, and keeps them in the environment so that the `octopus…`
    /// presentation modifiers can inject them again into what they present.
    func sharedEnvironmentObjects(_ objects: SharedEnvironmentObjects) -> some View {
        environmentObject(objects.translationStore)
            .environmentObject(objects.gamificationRulesViewManager)
            .environmentObject(objects.displayConfigManager)
            .environmentObject(objects.reactionsListManager)
            .environmentObject(objects.videoManager)
            .environmentObject(objects.languageManager)
            .environment(\.sharedEnvironmentObjects, objects)
    }

    /// `sheet(isPresented:onDismiss:content:)`, whose content is given the SDK's shared environment objects.
    func octopusSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content) -> some View {
        SharedEnvironmentObjectsReader { objects in
            sheet(isPresented: isPresented, onDismiss: onDismiss) {
                content().sharedEnvironmentObjects(ifAny: objects)
            }
        }
    }

    /// `sheet(item:onDismiss:content:)`, whose content is given the SDK's shared environment objects.
    func octopusSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        SharedEnvironmentObjectsReader { objects in
            sheet(item: item, onDismiss: onDismiss) {
                content($0).sharedEnvironmentObjects(ifAny: objects)
            }
        }
    }

    /// `fullScreenCover(isPresented:onDismiss:content:)` (a sheet on iOS 13), whose content is given the SDK's
    /// shared environment objects.
    func octopusFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content) -> some View {
        SharedEnvironmentObjectsReader { objects in
            fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
                content().sharedEnvironmentObjects(ifAny: objects)
            }
        }
    }

    /// `popover(isPresented:arrowEdge:content:)`, whose content is given the SDK's shared environment objects.
    func octopusPopover<Content: View>(
        isPresented: Binding<Bool>,
        arrowEdge: Edge = .top,
        @ViewBuilder content: @escaping () -> Content) -> some View {
        SharedEnvironmentObjectsReader { objects in
            popover(isPresented: isPresented, arrowEdge: arrowEdge) {
                content().sharedEnvironmentObjects(ifAny: objects)
            }
        }
    }
}

/// Reads the shared objects where a presentation is declared: the presenter has them, while the content it presents
/// may not have them yet.
private struct SharedEnvironmentObjectsReader<Presenter: View>: View {
    @Environment(\.sharedEnvironmentObjects) private var objects

    let presenter: (SharedEnvironmentObjects?) -> Presenter

    var body: some View {
        presenter(objects)
    }
}

private extension View {
    @ViewBuilder
    func sharedEnvironmentObjects(ifAny objects: SharedEnvironmentObjects?) -> some View {
        if let objects {
            sharedEnvironmentObjects(objects)
        } else {
            self
        }
    }
}
