//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
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
    var notificationService: NotificationService { get }
    var apiKeyService: ApiKeyService { get }

    func set(appSessionId: String?)
    func set(octopusUISessionId: String?)
    func set(hasAccessToCommunity: Bool?)
}

public class GrpcClient: OctopusRemoteClient {
    public var octoService: OctoService { _octoService }
    public var magicLinkService: MagicLinkService { _magicLinkService }
    public var magicLinkStreamService: MagicLinkStreamService { _magicLinkStreamService }
    public var userService: UserService { _userService }
    public var feedService: FeedService { _feedService }
    public var trackingService: TrackingService { _trackingService }
    public var notificationService: NotificationService { _notificationService }
    public var apiKeyService: ApiKeyService { _apiKeyService }

    private let _octoService: OctoServiceClient
    private let _magicLinkService: MagicLinkServiceClient
    private let _magicLinkStreamService: MagicLinkStreamingServiceClient
    private let _userService: UserServiceClient
    private let _feedService: FeedServiceClient
    private let _trackingService: TrackingServiceClient
    private let _notificationService: NotificationServiceClient
    private let _apiKeyService: ApiKeyServiceClient

    private let unaryChannel: GRPCChannel
    private let streamingChannel: GRPCChannel
    private let group = PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)

    private let serviceClients: [ServiceClient]

    public init(apiKey: String, sdkVersion: String, installId: String,
                getUserIdBlock: @escaping () -> String?,
                updateTokenBlock: @escaping (String) -> Void) throws {
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
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _magicLinkService = MagicLinkServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _magicLinkStreamService = MagicLinkStreamingServiceClient(
            streamingChannel: streamingChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId)
        _userService = UserServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _feedService = FeedServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _trackingService = TrackingServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _notificationService = NotificationServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _apiKeyService = ApiKeyServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)

        serviceClients = [_octoService, _magicLinkService, _magicLinkStreamService, _userService, _feedService,
                          _trackingService, _notificationService, _apiKeyService]
    }

    public func set(appSessionId: String?) {
        serviceClients.forEach { $0.appSessionId = appSessionId }
    }

    public func set(octopusUISessionId: String?) {
        serviceClients.forEach { $0.octopusUISessionId = octopusUISessionId }
    }

    public func set(hasAccessToCommunity: Bool?) {
        serviceClients.forEach { $0.hasAccessToCommunity = hasAccessToCommunity }
    }

    deinit {
        Task { [group] in
            try? await group.shutdownGracefully()
        }
    }
}
