//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

public extension OctopusSDK {
    /// SDK Configuration
    struct Configuration {
        /// If false, the SDK will set the AVAudioSession category to .playback or .ambient to ensure video audio plays
        /// in silent mode.
        /// Default is false.
        public let appManagedAudioSession: Bool

        /// Constructor
        /// - Parameters:
        ///   - appManagedAudioSession: If false, the SDK will set the AVAudioSession category to `.playback` or
        ///                             `.ambient` to ensure video audio plays in silent mode.
        ///                             Set it to `true` if you want to handle the configuration yourself. If set to
        ///                             `true`, we advise you to set the AVAudioSession category to `.playback` or
        ///                             `.ambient` with `mixWithOther` option in order to ensure that video's audio
        ///                             plays even in silent mode.
        ///                             Default is false.
        public init(appManagedAudioSession: Bool = false) {
            self.appManagedAudioSession = appManagedAudioSession
        }
    }
}

extension OctopusSDK.Configuration {
    var coreValue: OctopusSDKConfiguration {
        OctopusSDKConfiguration(appManagedAudioSession: appManagedAudioSession)
    }
}
