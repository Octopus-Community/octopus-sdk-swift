//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

public struct OctopusSDKConfiguration {
    /// Custom server endpoint the SDK targets. `nil` resolves to the Octopus default.
    public let apiServer: ApiServer?
    /// If false, the SDK will set the AVAudioSession category to .playback to ensure audio plays in silent mode.
    /// Default is false.
    public let appManagedAudioSession: Bool

    /// Constructor
    /// - Parameters:
    ///   - apiServer: Custom server endpoint the SDK targets. When `nil`, the SDK uses the Octopus default.
    ///   - appManagedAudioSession: If false, the SDK will set the AVAudioSession category to .playback to ensure audio
    ///                             plays in silent mode.
    ///                             Set it to `true` if you want to handle the configuration yourself.
    ///                             Default is false.
    public init(
        apiServer: ApiServer? = nil,
        appManagedAudioSession: Bool = false
    ) {
        self.apiServer = apiServer
        self.appManagedAudioSession = appManagedAudioSession
    }
}

public extension OctopusSDKConfiguration {
    /// Internal Core mirror of the public ``OctopusSDK/Configuration/ApiServer``.
    /// Validation has already happened on the public side — this struct does not re-validate.
    struct ApiServer {
        public let host: String
        public let port: Int

        public init(host: String, port: Int = 443) {
            self.host = host
            self.port = port
        }
    }
}
