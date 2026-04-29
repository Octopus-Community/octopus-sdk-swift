//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import os
import Octopus
import OctopusCore

final class VideoManager: ObservableObject {
    // We do not used @Published to avoid some UI glitches when value changes during list scroll
    let playingVideoId = CurrentValueSubject<String?, Never>(nil)
    @Published var isMuted = true {
        didSet { configureAudioSession() }
    }

    private let updateWatchTimeHandler: (_ contentId: String, _ videoId: String,
                                          _ currentWatchTime: TimeInterval, _ duration: TimeInterval) -> Void
    private let increaseCompletionHandler: (_ contentId: String, _ videoId: String,
                                             _ duration: TimeInterval) -> Void
    private let appManagedAudioSession: Bool
    private var currentTimes: [String: TimeInterval] = [:]
    private var audioSessionActive = false

    private var storage = [AnyCancellable]()

    /// Designated init. Accepts closures for repository side effects and a boolean that controls
    /// whether the app manages its own audio session (in which case this manager never touches
    /// `AVAudioSession`). Used directly by previews/tests.
    init(
        updateWatchTime: @escaping (_ contentId: String, _ videoId: String,
                                    _ currentWatchTime: TimeInterval, _ duration: TimeInterval) -> Void,
        increaseCompletion: @escaping (_ contentId: String, _ videoId: String,
                                       _ duration: TimeInterval) -> Void,
        appManagedAudioSession: Bool
    ) {
        self.updateWatchTimeHandler = updateWatchTime
        self.increaseCompletionHandler = increaseCompletion
        self.appManagedAudioSession = appManagedAudioSession
    }

    /// Production convenience.
    convenience init(octopus: OctopusSDK) {
        let repo = octopus.core.videosRepository
        self.init(
            updateWatchTime: { contentId, videoId, currentWatchTime, duration in
                repo.updateWatchTime(contentId: contentId, videoId: videoId,
                                     currentWatchTime: currentWatchTime, duration: duration)
            },
            increaseCompletion: { contentId, videoId, duration in
                repo.increaseCompletion(contentId: contentId, videoId: videoId, duration: duration)
            },
            appManagedAudioSession: octopus.core.sdkConfig.appManagedAudioSession)
    }

    /// Preview factory — no-op handlers; `appManagedAudioSession: true` means `AVAudioSession`
    /// is never touched.
    static func forPreviews() -> VideoManager {
        VideoManager(
            updateWatchTime: { _, _, _, _ in },
            increaseCompletion: { _, _, _ in },
            appManagedAudioSession: true)
    }

    func set(autoPlayVideoId: String?) {
        setPlayingVideoId(autoPlayVideoId)
    }

    func video(id: String, isPlaying: Bool) {
        if isPlaying {
            setPlayingVideoId(id)
        } else {
            guard id == playingVideoId.value else { return }
            setPlayingVideoId(nil)
        }
    }

    private func setPlayingVideoId(_ videoId: String?) {
        guard videoId != playingVideoId.value else { return }
        if videoId != nil {
            willPlay()
        }
        playingVideoId.send(videoId)
        if videoId == nil {
            didPause()
        }
    }

    func updateWatchTime(contentId: String, videoId: String, currentWatchTime: TimeInterval, duration: TimeInterval) {
        updateWatchTimeHandler(contentId, videoId, currentWatchTime, duration)
        currentTimes[videoId] = currentWatchTime
    }

    func increaseCompletion(contentId: String, videoId: String, duration: TimeInterval) {
        increaseCompletionHandler(contentId, videoId, duration)
    }

    func getCurrentTime(videoId: String) -> TimeInterval? {
        currentTimes[videoId]
    }

    private func willPlay() {
        configureAudioSession()
        guard !appManagedAudioSession else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func didPause() {
        guard !appManagedAudioSession else { return }
        DispatchQueue.global(qos: .background).async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func configureAudioSession() {
        guard !appManagedAudioSession else { return }
        let session = AVAudioSession.sharedInstance()

        if isMuted {
            // Category .ambient allows background music to keep playing
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        } else {
            // Category .playback stops background music
            try? session.setCategory(.playback, mode: .default)
        }
    }
}
