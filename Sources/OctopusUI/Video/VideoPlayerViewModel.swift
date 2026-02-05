//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import AVFoundation
import UIKit

@MainActor
class VideoPlayerViewModel: NSObject, ObservableObject {
    private(set) var playerItem: AVPlayerItem?
    let player: AVPlayer = AVPlayer()
    private var url: URL?

    @Published private(set) var isBuffering: Bool = true
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var hasError: Bool = false
    @Published private(set) var duration: TimeInterval = 0.0
    @Published private(set) var currentTime: TimeInterval = 0.0
    @Published private(set) var isMuted = true
    @Published private(set) var isReadyToPlay = false

    @Published var isDisplayed: Bool = false
    @Published private var isInBackground: Bool = false

    private let videoManager: VideoManager
    private let contentId: String
    private let videoId: String
    private var timer: Timer?

    private var timeObserver: Any?
    private var storage = [AnyCancellable]()
    private var playerItemStorage = [AnyCancellable]()
    private var shouldResumePlay = false

    init(videoManager: VideoManager, contentId: String, videoId: String) {
        self.videoManager = videoManager
        self.contentId = contentId
        self.videoId = videoId
        super.init()

        videoManager.$isMuted.removeDuplicates().sink { [unowned self] in
            isMuted = $0
            player.isMuted = $0
        }.store(in: &storage)
    }

    func set(url: URL) {
        guard url != self.url || playerItem?.error != nil else { return }
        hasError = false
        self.url = url
        if let playerItem {
            NotificationCenter.default.removeObserver(self, name: AVPlayerItem.didPlayToEndTimeNotification, object: playerItem)
            NotificationCenter.default.removeObserver(self, name: AVPlayerItem.failedToPlayToEndTimeNotification, object: playerItem)
            NotificationCenter.default.removeObserver(self, name: AVPlayerItem.playbackStalledNotification, object: playerItem)
            playerItemStorage.removeAll()
        }
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 1
        playerItem = item
        player.replaceCurrentItem(with: item)
        player.isMuted = isMuted
        if let currentTime = videoManager.getCurrentTime(videoId: videoId) {
            player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 1))
        }

        player.publisher(for: \.timeControlStatus).sink { [unowned self] timeControlStatus in
            isPlaying = timeControlStatus != .paused
        }.store(in: &playerItemStorage)

        item.publisher(for: \.status).sink { [unowned self] status in
            isReadyToPlay = status == .readyToPlay
            if isReadyToPlay, let durationInSeconds = player.currentItem?.duration.seconds,
               durationInSeconds.isFinite, durationInSeconds != duration {
                duration = durationInSeconds
            }
            hasError = status == .failed
        }.store(in: &playerItemStorage)

        player.publisher(for: \.reasonForWaitingToPlay)
            // debounce because pressing play will quickly move to `evaluatingBufferingRate` and after nil if everything
            // is correct
            .debounce(for: 0.1, scheduler: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isBuffering = status != nil
            }.store(in: &playerItemStorage)

        NotificationCenter.default
            .publisher(for: AVPlayerItem.didPlayToEndTimeNotification)
            .sink { [unowned self] _ in
                if let durationInSeconds = player.currentItem?.duration.seconds, durationInSeconds.isFinite {
                    currentTime = durationInSeconds
                    videoManager.video(id: videoId, isPlaying: false)
                }
            }.store(in: &playerItemStorage)

        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [unowned self] _ in
                isInBackground = true
            }
            .store(in: &playerItemStorage)

        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [unowned self] _ in
                isInBackground = false
            }.store(in: &playerItemStorage)

        NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .sink { [unowned self] _ in
                isInBackground = true
            }
            .store(in: &playerItemStorage)

        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [unowned self] _ in
                isInBackground = false
            }.store(in: &playerItemStorage)

        let interval = CMTime(value: 1, timescale: 2)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval,
                                                      queue: .main) { [weak self] time in
            guard let self else { return }
            MainActor.assumeIsolated { [weak self] in // because we explicitely set the main queue in the addPeriodicTimeObserver
                guard let self else { return }
                let newDuration: TimeInterval
                if let durationInSeconds = player.currentItem?.duration.seconds, durationInSeconds.isFinite {
                    newDuration = durationInSeconds
                } else {
                    newDuration = 0
                }
                if duration != newDuration {
                    duration = newDuration
                }

                // Update the published currentTime and duration values.
                currentTime = time.seconds
                if duration > 0 {
                    videoManager.updateWatchTime(contentId: contentId, videoId: videoId, currentWatchTime: currentTime,
                                                 duration: duration)
                }
            }
        }

        Publishers.CombineLatest(
            $isDisplayed.removeDuplicates(),
            $isInBackground.removeDuplicates()
        ).sink { [unowned self] isDisplayed, isInBackground in
            if isDisplayed && !isInBackground {
                resumePlayIfNeeded()
            } else if !isDisplayed || isInBackground {
                pauseTemporary()
            }
        }.store(in: &playerItemStorage)

        videoManager.playingVideoId.removeDuplicates().sink { [unowned self] autoplayContentId in
            guard isDisplayed else { return }
            let autoPlay = autoplayContentId == videoId
            guard autoPlay != isPlaying else { return }
            if autoPlay {
                doPlay()
            } else {
                doPause()
            }
        }.store(in: &playerItemStorage)
    }

    func play() {
        if videoManager.playingVideoId.value != videoId {
            videoManager.video(id: videoId, isPlaying: true)
        } else {
            doPlay()
        }
    }

    func pause() {
        videoManager.video(id: videoId, isPlaying: false)
    }

    func pauseTemporary() {
        if isPlaying {
            shouldResumePlay = true
            doPause()
        }
    }

    func resumePlayIfNeeded() {
        if shouldResumePlay {
            shouldResumePlay = false
            if let currentTime = videoManager.getCurrentTime(videoId: videoId) {
                player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 1))
            }
            doPlay()
        }
    }

    func togglePlayPause() {
        if !hasError, isPlaying {
            pause()
        } else {
            play()
        }
    }

    func toggleSound() {
        videoManager.isMuted.toggle()
    }

    private func doPlay() {
        if hasError, let url {
            set(url: url)
        }
        // If video finished, seek to start before playing
        if let currentItem = player.currentItem, player.currentTime() >= currentItem.duration {
            player.seek(to: .zero)
            videoManager.increaseCompletion(contentId: contentId, videoId: videoId, duration: duration)
        }
        player.play()
        isPlaying = true
    }

    private func doPause() {
        player.pause()
        isPlaying = false
    }
}
