//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

private struct PostsVisibilityScrollView: ViewModifier {
    @EnvironmentObject private var videoManager: VideoManager

    @State private var lastEmissionDate = Date.distantPast
    @State private var pendingValue: VisibleItemsPreference<VisiblePost>.Value?
    @State private var throttleTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .onPreferenceChange(VisibleItemsPreference<VisiblePost>.self) { value in
                    let now = Date()
                    let interval: TimeInterval = 0.3

                    // If outside the throttle window → emit immediately
                    if now.timeIntervalSince(lastEmissionDate) >= interval {
                        lastEmissionDate = now
                        handleVisibility(proxy, value)
                        return
                    }

                    // Otherwise, store the latest value for trailing emission
                    pendingValue = value

                    // Schedule trailing emission once per window
                    if throttleTask == nil {
                        let delay = interval - now.timeIntervalSince(lastEmissionDate)

                        throttleTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            defer { throttleTask = nil }

                            guard let pendingValue else { return }

                            lastEmissionDate = Date()
                            handleVisibility(proxy, pendingValue)
                            self.pendingValue = nil
                        }
                    }
                }
        }
    }

    private func handleVisibility(_ proxy: GeometryProxy,
        _ value: VisibleItemsPreference<VisiblePost>.Value
    ) {
        let myFrame = proxy.frame(in: .local)

        let itemsVisibility = value
            .sorted { $0.item.position < $1.item.position }
            .map {
                ItemVisibility(
                    containerBounds: myFrame,
                    bounds: proxy[$0.bounds],
                    item: $0.item
                )
            }

        let visibleItems = itemsVisibility.filter { $0.isPartiallyVisible }

        if let first = visibleItems.first,
           first.item.position == 0,
           first.item.hasVideo,
           first.topIsVisible {
            videoManager.set(autoPlayVideoId: first.item.videoId)
        } else if let last = visibleItems.last,
                  last.item.isLast,
                  last.item.hasVideo,
                  last.bottomIsVisible {
            videoManager.set(autoPlayVideoId: last.item.videoId)
        } else {
            let centerItems = visibleItems.sorted { $0.centerProximity < $1.centerProximity }
            let autoPlayContentId = centerItems
                .first { $0.isFullyVisible && $0.item.hasVideo }
                .map { $0.item.videoId }
            if let autoPlayContentId {
                videoManager.set(autoPlayVideoId: autoPlayContentId)
            }
            else if let currentlyPlayingVideo = videoManager.playingVideoId.value {
                if !visibleItems.contains(where: { $0.item.videoId == currentlyPlayingVideo }) {
                    videoManager.set(autoPlayVideoId: nil)
                }
            }
        }
    }
}

extension View {
    /// Decorator of a scroll view that will display posts.
    /// This view modifier will add computation of item visibility (for the moment, only used to auto play videos)
    @ViewBuilder
    func postsVisibilityScrollView() -> some View {
        self.modifier(PostsVisibilityScrollView())
    }
}
