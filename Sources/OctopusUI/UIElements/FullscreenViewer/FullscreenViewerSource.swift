//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// Where a source of the fullscreen viewer is on screen, read when it is tapped.
///
/// The geometry is read on demand rather than followed: following the frame of a photo in a feed would update a
/// state on every frame of a scroll.
@MainActor
final class FullscreenViewerSourceGeometry {
    private var proxy: GeometryProxy?
    /// The recorder that gave `proxy`.
    private var recorder: UUID?

    nonisolated init() {}

    /// The frame of the source in the global coordinate space, as it is now. `nil` before it is laid out, and once it
    /// is no longer on screen.
    var frame: CGRect? {
        guard let frame = proxy?.frame(in: .global), !frame.isEmpty else { return nil }
        return frame
    }

    fileprivate func record(_ proxy: GeometryProxy, from recorder: UUID) {
        self.proxy = proxy
        self.recorder = recorder
    }

    /// Forgets the proxy of a recorder that left the screen, unless another recorder gave one since: the order in
    /// which SwiftUI reports a view that leaves and the one that replaces it is not guaranteed.
    fileprivate func forget(from recorder: UUID) {
        guard self.recorder == recorder else { return }
        proxy = nil
        self.recorder = nil
    }
}

extension View {
    /// Makes this view a source of the fullscreen viewer.
    ///
    /// - Parameters:
    ///   - geometry: gives the frame of this view, when it is tapped.
    ///   - isInViewer: whether the viewer shows the photos of this view. The view is then hidden, from the flight
    ///     that opens the viewer until the end of the one that brings the photo back: the viewer cannot hide a
    ///     SwiftUI view, and the photo would be on screen twice.
    func fullscreenViewerSource(_ geometry: FullscreenViewerSourceGeometry, isInViewer: Bool) -> some View {
        background(GeometryReader { proxy in
            SourceGeometryRecorder(proxy: proxy, geometry: geometry)
        })
        .opacity(isInViewer ? 0 : 1)
    }
}

/// Keeps the latest proxy of the source. It does not read the geometry, so that a scroll does not evaluate it again.
private struct SourceGeometryRecorder: View {
    let proxy: GeometryProxy
    let geometry: FullscreenViewerSourceGeometry
    @State private var id = UUID()

    var body: some View {
        geometry.record(proxy, from: id)
        return Color.clear
            .onAppear { geometry.record(proxy, from: id) }
            // The proxy of a view taken off the screen, by a refresh of the feed for instance, still answers with
            // its last frame, which another view may hold now: the photo would fly back there.
            .onDisappear { geometry.forget(from: id) }
    }
}
