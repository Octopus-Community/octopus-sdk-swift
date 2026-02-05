//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import AVFoundation

struct VideoPlayerView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var videoManager: VideoManager

    let videoMedia: VideoMedia
    let width: CGFloat
    @Compat.StateObject private var viewModel: VideoPlayerViewModel

    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?

    @Compat.ScaledMetric(relativeTo: .largeTitle) private var btInternalVPadding: CGFloat = 8
    @Compat.ScaledMetric(relativeTo: .largeTitle) private var btInternalHPadding: CGFloat = 12

    init(videoManager: VideoManager, videoMedia: VideoMedia, contentId: String, width: CGFloat) {
        self.videoMedia = videoMedia
        self._viewModel = Compat.StateObject(wrappedValue: VideoPlayerViewModel(videoManager: videoManager,
                                                                                contentId: contentId,
                                                                                videoId: videoMedia.videoId))
        self.width = width
    }

    var body: some View {
        ZStack {
            VideoLayerView(player: viewModel.player)
                .onAppear {
                    viewModel.isDisplayed = true
                    // Initialize player when view appears
                    viewModel.set(url: videoMedia.url)
                }
                .onDisappear {
                    viewModel.isDisplayed = false
                }
                // This ensures the view takes up all available width
                .frame(maxWidth: .infinity)
                .aspectRatio(videoMedia.size.width/videoMedia.size.height, contentMode: .fit)
                .modify {
                    if #unavailable(iOS 17.0) {
                        $0.fixedSize(horizontal: false, vertical: true)
                    } else { $0 }
                }

            if (!viewModel.isReadyToPlay || viewModel.currentTime == 0), let thumbnailUrl = videoMedia.thumbnailUrl {
                AsyncCachedImage(
                    url: thumbnailUrl, cache: .thumbnail,
                    placeholder: {
                        theme.colors.gray200
                            .aspectRatio(videoMedia.size.width/videoMedia.size.height, contentMode: .fit)
                            .clipped()
                    },
                    content: { cachedImage in
                        Image(uiImage: cachedImage.fullSizeImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                )
                .modify {
                    if #unavailable(iOS 17.0) {
                        $0.fixedSize(horizontal: false, vertical: true)
                    } else { $0 }
                }
            }

            if (!viewModel.isReadyToPlay || viewModel.isBuffering) && !viewModel.hasError {
                Compat.ProgressView(tint: theme.colors.hover)
                    .padding(btInternalHPadding)
                    .background(
                        Circle().foregroundColor(theme.colors.gray800.opacity(0.3))
                    )
            } else if isEnded {
                Text("Content.Video.Replay", bundle: .module)
                    .font(theme.fonts.body2)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.hover)
                    .padding(.vertical, btInternalVPadding)
                    .padding(.horizontal, btInternalHPadding)
                    .background(
                        Capsule().foregroundColor(theme.colors.gray800.opacity(0.6))
                    )
                    .padding(10)
                    .opacity(showControls ? 1 : 0)
            }

            VStack {
                Spacer()
                VideoControlsBottomBar(
                    isPlaying: viewModel.isPlaying,
                    isEnded: isEnded,
                    hasError: viewModel.hasError,
                    isMuted: viewModel.isMuted,
                    currentTime: viewModel.currentTime,
                    duration: viewModel.duration,
                    togglePlayPause: viewModel.togglePlayPause,
                    toggleSound: viewModel.toggleSound
                )
            }
            .opacity(showControls ? 1 : 0)
        }
        .contentShape(Rectangle()) // ensures taps register everywhere
        .onTapGesture {
            if !showControls {
                withAnimation {
                    showControls.toggle()
                }
                scheduleControlsHide()
            } else {
                viewModel.togglePlayPause()
            }
        }
        .modify {
            if #unavailable(iOS 17.0) {
                $0.frame(width: width)
            } else { $0 }
        }
        .onValueChanged(of: viewModel.isPlaying) { isPlaying in
            if isPlaying {
                scheduleControlsHide()
            } else {
                hideControlsTask?.cancel()
                withAnimation {
                    showControls = true
                }
            }
        }
    }

    private func scheduleControlsHide() {
        hideControlsTask?.cancel()

        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation {
                    showControls = false
                }
            }
        }
    }

    var isEnded: Bool {
        viewModel.currentTime >= viewModel.duration && viewModel.duration > 0
    }
}

private struct VideoControlsBottomBar: View {
    @Environment(\.octopusTheme) private var theme

    let isPlaying: Bool
    let isEnded: Bool
    let hasError: Bool
    let isMuted: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    let togglePlayPause: () -> Void
    let toggleSound: () -> Void

    @Compat.ScaledMetric(relativeTo: .largeTitle) var btInternalPadding: CGFloat = 8 // largeTitle to vary from 7 to 13
    @Compat.ScaledMetric(relativeTo: .largeTitle) var iconSize: CGFloat = 24 // largeTitle to vary from 22 to 41

    let padding: CGFloat = 10

    var body: some View {
        HStack(spacing: 0) {
            Button(action: togglePlayPause) {
                Image(res: togglePlayPauseIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(theme.colors.hover)
                    .accessibilityLabelInBundle(togglePlayPauseAccessibilityKey)
                    .padding(btInternalPadding)
                    .background(
                        Circle()
                            .foregroundColor(theme.colors.gray800.opacity(0.6))
                    )
                    .padding(padding)
            }
            .buttonStyle(.plain)

            Spacer()

            let displayHours = duration >= 3600
            let currentTimeStr = String.formattedDuration(currentTime, displayHours: displayHours)
            let durationStr = String.formattedDuration(duration, displayHours: displayHours)
            Text(verbatim: "\(currentTimeStr) / \(durationStr)")
                .font(theme.fonts.body2)
                .fontWeight(.medium)
                .modify {
                    if #available(iOS 15.0, *) {
                        $0.monospacedDigit()
                    } else { $0 }
                }
                .foregroundColor(theme.colors.hover)
                .padding(btInternalPadding)
                .background(
                    Capsule().foregroundColor(theme.colors.gray800.opacity(0.6))
                )
                .padding([.vertical, .leading], padding)

            Button(action: toggleSound) {
                Image(res: isMuted ? .Video.muted : .Video.notMuted)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(theme.colors.hover)
                    .accessibilityLabelInBundle(isMuted ? "Accessibility.Video.Unmute" : "Accessibility.Video.Mute")
                    .padding(btInternalPadding)
                    .background(
                        Circle()
                            .foregroundColor(theme.colors.gray800.opacity(0.6))
                    )
                    .padding(padding)
            }
            .buttonStyle(.plain)
        }
    }

    var togglePlayPauseIcon: GenImageResource {
        if isEnded || hasError {
            .Video.replay
        } else if isPlaying {
            .Video.pause
        } else {
            .Video.play
        }
    }

    var togglePlayPauseAccessibilityKey: LocalizedStringKey {
        if isEnded || hasError {
            "Content.Video.Replay"
        } else if isPlaying {
            "Accessibility.Video.Pause"
        } else {
            "Accessibility.Video.Play"
        }
    }
}

// MARK: - Internal AVPlayerLayer Wrapper
private struct VideoLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect // Matches "fit width" behavior
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let playerView = uiView as? PlayerUIView else { return }
        playerView.playerLayer.player = player
    }

    // A simple UIView subclass to expose the AVPlayerLayer
    class PlayerUIView: UIView {
        override static var layerClass: AnyClass {
            return AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }
    }
}
