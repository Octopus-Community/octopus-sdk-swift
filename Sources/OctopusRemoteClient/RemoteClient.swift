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
    var trackingService: TrackingService { get }

    func set(appSessionId: String?)
    func set(octopusUISessionId: String?)
}

public class GrpcClient: OctopusRemoteClient {
    public var octoService: OctoService { _octoService }
    public var magicLinkService: MagicLinkService { _magicLinkService }
    public var magicLinkStreamService: MagicLinkStreamService { _magicLinkStreamService }
    public var userService: UserService { _userService }
    public var feedService: FeedService { _feedService }
    public var trackingService: TrackingService { _trackingService }

    private let _octoService: OctoServiceClient
    private let _magicLinkService: MagicLinkServiceClient
    private let _magicLinkStreamService: MagicLinkStreamingServiceClient
    private let _userService: UserServiceClient
    private let _feedService: FeedServiceClient
    private let _trackingService: TrackingServiceClient

    private let unaryChannel: GRPCChannel
    private let streamingChannel: GRPCChannel
    private let group = PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)

    public init(apiKey: String, sdkVersion: String, installId: String, updateTokenBlock: @escaping (String) -> Void) throws {
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
        
        _octoService = OctoServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            updateTokenBlock: updateTokenBlock)
        _magicLinkService = MagicLinkServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            updateTokenBlock: updateTokenBlock)
        _magicLinkStreamService = MagicLinkStreamingServiceClient(
            streamingChannel: streamingChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            updateTokenBlock: updateTokenBlock)
        _userService = UserServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            updateTokenBlock: updateTokenBlock)
        _feedService = FeedServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            updateTokenBlock: updateTokenBlock)
        _trackingService = TrackingServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            updateTokenBlock: updateTokenBlock)
    }

    public func set(appSessionId: String?) {
        _octoService.appSessionId = appSessionId
        _magicLinkService.appSessionId = appSessionId
        _magicLinkStreamService.appSessionId = appSessionId
        _userService.appSessionId = appSessionId
        _feedService.appSessionId = appSessionId
        _trackingService.appSessionId = appSessionId
    }

    public func set(octopusUISessionId: String?) {
        _octoService.octopusUISessionId = octopusUISessionId
        _magicLinkService.octopusUISessionId = octopusUISessionId
        _magicLinkStreamService.octopusUISessionId = octopusUISessionId
        _userService.octopusUISessionId = octopusUISessionId
        _feedService.octopusUISessionId = octopusUISessionId
        _trackingService.octopusUISessionId = octopusUISessionId
    }

    deinit {
        try? group.syncShutdownGracefully()
    }
}
