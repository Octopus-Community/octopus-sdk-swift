//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

public struct OctopusSDKConfiguration {
    /// If false, the SDK will set the AVAudioSession category to .playback to ensure audio plays in silent mode.
    /// Default is false.
    public let appManagedAudioSession: Bool

    /// Constructor
    /// - Parameters:
    ///   - appManagedAudioSession: If false, the SDK will set the AVAudioSession category to .playback to ensure audio
    ///                             plays in silent mode.
    ///                             Set it to `true` if you want to handle the configuration yourself.
    ///                             Default is false.
    public init(appManagedAudioSession: Bool = false) {
        self.appManagedAudioSession = appManagedAudioSession
    }
}
