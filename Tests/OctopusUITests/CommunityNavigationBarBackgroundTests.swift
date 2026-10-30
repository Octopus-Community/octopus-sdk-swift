//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import Testing
import UIKit
@testable import OctopusUI

@MainActor
struct CommunityNavigationBarBackgroundTests {
    private let communityBackground = UIColor(red: 0.98, green: 0.92, blue: 0.84, alpha: 1)
    private let probe = ViewProbe()

    @Test func withoutGlassTheScrolledBarTakesTheCommunityBackground() async throws {
        guard #available(iOS 16.0, *) else { return }
        var navigationBar: UINavigationBar?
        try await renderInWindow(screen(glassEffectAvailable: false), until: {
            navigationBar = findNavigationBar()
            return barBackground(navigationBar) != nil
        })
        #expect(barBackground(navigationBar) == communityBackground)
    }

    @Test func withGlassTheBarKeepsItsDefaultBackground() async throws {
        var navigationBar: UINavigationBar?
        try await renderInWindow(screen(glassEffectAvailable: true), until: {
            navigationBar = findNavigationBar()
            return navigationBar?.topItem != nil
        })
        #expect(barBackground(navigationBar) != communityBackground)
    }

    private func screen(glassEffectAvailable: Bool) -> some View {
        NavigationView {
            ScrollView {
                ForEach(0..<50, id: \.self) { Text("Row \($0)") }
            }
            .background(ViewProbe.Representable(probe: probe))
            .navigationBarTitle(Text(verbatim: "Groups"), displayMode: .inline)
            .communityNavigationBarBackground(glassEffectAvailable: glassEffectAvailable)
        }
        .navigationViewStyle(.stack)
        .environment(\.octopusTheme, OctopusTheme(colors: .init(background: Color(communityBackground))))
    }

    /// The background of the bar drawn once the content scrolls under it (the standard appearance), as
    /// SwiftUI sets it on the screen's navigation item.
    private func barBackground(_ navigationBar: UINavigationBar?) -> UIColor? {
        navigationBar?.topItem?.standardAppearance?.backgroundColor
    }

    private func findNavigationBar() -> UINavigationBar? {
        guard let window = probe.view?.window else { return nil }
        return firstNavigationBar(in: window)
    }

    private func firstNavigationBar(in view: UIView) -> UINavigationBar? {
        if let bar = view as? UINavigationBar { return bar }
        for subview in view.subviews {
            if let bar = firstNavigationBar(in: subview) { return bar }
        }
        return nil
    }
}

/// Gives the test the `UIView` SwiftUI puts in the hierarchy, to reach its window: the test host runs without
/// scenes, so `UIApplication.shared.windows` is empty.
@MainActor
private final class ViewProbe {
    weak var view: UIView?

    struct Representable: UIViewRepresentable {
        let probe: ViewProbe

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            probe.view = view
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {}
    }
}
