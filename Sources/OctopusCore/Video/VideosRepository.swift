//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusRemoteClient
import os
import OctopusDependencyInjection
import OctopusGrpcModels


extension Injected {
    static let videosRepository = Injector.InjectedIdentifier<VideosRepository>()
}

public class VideosRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.videosRepository

    /// Watch time infos used for analytics. Emptied when `collectTrackedWatchTimeInfos` is called.
    /// Indexed by video id.
    private var trackedWatchTimeInfos: [String: VideoWatchTimeInfo] = [:]

    init(injector: Injector) { }

    public func updateWatchTime(contentId: String, videoId: String, currentWatchTime: TimeInterval,
                                duration: TimeInterval) {
        var currentInfo = trackedWatchTimeInfos[videoId, default: .init(contentId: contentId, videoId: videoId,
                                                                        duration: duration,
                                                                        currentWatchTime: 0, completionCount: 0)]
        currentInfo.currentWatchTime = currentWatchTime
        trackedWatchTimeInfos[videoId] = currentInfo
    }

    public func increaseCompletion(contentId: String, videoId: String, duration: TimeInterval) {
        var currentInfo = trackedWatchTimeInfos[videoId, default: .init(contentId: contentId, videoId: videoId,
                                                                        duration: duration,
                                                                        currentWatchTime: 0, completionCount: 0)]
        currentInfo.completionCount += 1
        currentInfo.currentWatchTime = 0
        trackedWatchTimeInfos[videoId] = currentInfo
    }

    func collectTrackedWatchTimeInfos() -> [VideoWatchTimeInfo] {
        let currentValues = Array(trackedWatchTimeInfos.values)
        trackedWatchTimeInfos = [:]
        return currentValues
    }
}
