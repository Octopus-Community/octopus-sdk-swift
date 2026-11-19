//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import Testing
import UIKit
@testable import OctopusUI

/// Where a source of the fullscreen viewer is on screen, as the viewer reads it when it opens and when it closes.
@MainActor
struct FullscreenViewerSourceTests {
    @Test func frameFollowsAScroll() async throws {
        let geometry = FullscreenViewerSourceGeometry()
        let host = UIHostingController(rootView: ScrollingSource(geometry: geometry))
        try await renderInWindow(host) {
            geometry.frame?.size == CGSize(width: 100, height: 50) && scrollView(in: host.view) != nil
        } andThen: {
            // Not named after `scrollView(in:)`: older compilers take the call in `#require` for the variable.
            let scroller = try #require(scrollView(in: host.view))
            let before = try #require(geometry.frame)

            // From where it starts, below the safe area.
            scroller.contentOffset.y += 80

            // Read on demand, without anything recording it again: the frame is the one of now.
            try await waitUntil { geometry.frame.map { abs($0.minY - (before.minY - 80)) < 0.5 } ?? false }
            #expect(geometry.frame?.minX == before.minX)
        }
    }

    @Test func frameIsForgottenOnceTheSourceLeaves() async throws {
        let geometry = FullscreenViewerSourceGeometry()
        let model = SourceModel()
        let host = UIHostingController(rootView: RemovableSource(geometry: geometry, model: model))
        try await renderInWindow(host) {
            geometry.frame != nil
        } andThen: {
            // A refresh of the feed, or a moderated post taken away, while the viewer is open.
            model.isShown = false
            try await waitUntil { geometry.frame == nil }
            #expect(geometry.frame == nil)

            model.isShown = true
            try await waitUntil { geometry.frame != nil }
            #expect(geometry.frame?.size == CGSize(width: 100, height: 50))
        }
    }
}

@MainActor
private func renderInWindow(_ host: UIViewController, until condition: () -> Bool,
                            andThen next: @MainActor () async throws -> Void) async throws {
    // The test host runs without scenes, so the window is attached to the screen directly.
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
    window.rootViewController = host
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    try await waitUntil(condition)
    try await next()
}

@MainActor
private func scrollView(in view: UIView) -> UIScrollView? {
    if let scrollView = view as? UIScrollView { return scrollView }
    return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
}

private struct ScrollingSource: View {
    let geometry: FullscreenViewerSourceGeometry

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear.frame(height: 100)
                Color.red
                    .frame(width: 100, height: 50)
                    .fullscreenViewerSource(geometry, isInViewer: false)
                Color.clear.frame(height: 2000)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

@MainActor
private final class SourceModel: ObservableObject {
    @Published var isShown = true
}

private struct RemovableSource: View {
    let geometry: FullscreenViewerSourceGeometry
    @ObservedObject var model: SourceModel

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 100)
            if model.isShown {
                Color.red
                    .frame(width: 100, height: 50)
                    .fullscreenViewerSource(geometry, isInViewer: false)
            }
            Spacer()
        }
    }
}
