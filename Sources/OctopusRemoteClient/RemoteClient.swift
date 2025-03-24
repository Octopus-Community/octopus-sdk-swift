//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import OctopusGrpcModels
import Logging
import NIOCore
import NIOPosix
import NIOHPACK

public protocol OctopusRemoteClient {
    var magicLinkStreamService: MagicLinkStreamService { get }
    var magicLinkService: MagicLinkService { get }
    var octoService: OctoService { get }
    var userService: UserService { get }
    var feedService: FeedService { get }
}

public class GrpcClient: OctopusRemoteClient {
    public let octoService: OctoService
    public let magicLinkService: MagicLinkService
    public let magicLinkStreamService: MagicLinkStreamService
    public let userService: UserService
    public let feedService: FeedService

    private let unaryChannel: GRPCChannel
    private let streamingChannel: GRPCChannel
    private let group = PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)

    public init(apiKey: String, sdkVersion: String, updateTokenBlock: @escaping (String) -> Void) throws {
        // base URL can be overriden by env vars. This is used for the internal demo app for example
        let baseUrl: String = if let customBaseUrl = Bundle.main.infoDictionary?["OCTOPUS_REMOTE_BASE_URL"] as? String,
                                 !customBaseUrl.isEmpty {
            customBaseUrl
        } else { "api.8pus.io" }

        unaryChannel = try GRPCChannelPool.with(
            configuration: GRPCChannelPool.Configuration.with(
                target: .host(baseUrl, port: 443),
                transportSecurity: .tls(.makeClientConfigurationBackedByNIOSSL()),
                eventLoopGroup: group))

        streamingChannel = try GRPCChannelPool.with(
            configuration: GRPCChannelPool.Configuration.with(
                target: .host("realtime-\(baseUrl)", port: 443),
                transportSecurity: .tls(.makeClientConfigurationBackedByNIOSSL()),
                eventLoopGroup: group))
        
        octoService = OctoServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, updateTokenBlock: updateTokenBlock)
        magicLinkService = MagicLinkServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, updateTokenBlock: updateTokenBlock)
        magicLinkStreamService = MagicLinkStreamingServiceClient(
            streamingChannel: streamingChannel, apiKey: apiKey, sdkVersion: sdkVersion,
            updateTokenBlock: updateTokenBlock)
        userService = UserServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, updateTokenBlock: updateTokenBlock)
        feedService = FeedServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, updateTokenBlock: updateTokenBlock)
    }
    
    deinit {
        try? group.syncShutdownGracefully()
    }
}
