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

    private let octopus: OctopusSDK
    let videosRepository: VideosRepository
    private var currentTimes: [String: TimeInterval] = [:]
    private var audioSessionActive = false

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus
        videosRepository = octopus.core.videosRepository
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
        videosRepository.updateWatchTime(contentId: contentId, videoId: videoId, currentWatchTime: currentWatchTime,
                                         duration: duration)
        currentTimes[videoId] = currentWatchTime
    }

    func increaseCompletion(contentId: String, videoId: String, duration: TimeInterval) {
        videosRepository.increaseCompletion(contentId: contentId, videoId: videoId, duration: duration)
    }

    func getCurrentTime(videoId: String) -> TimeInterval? {
        currentTimes[videoId]
    }

    private func willPlay() {
        configureAudioSession()
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func didPause() {
        DispatchQueue.global(qos: .background).async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func configureAudioSession() {
        guard !octopus.core.sdkConfig.appManagedAudioSession else { return }
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
