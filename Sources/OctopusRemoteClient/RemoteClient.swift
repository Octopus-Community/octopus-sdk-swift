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
import NIOCore
import NIOPosix
import NIOHPACK

public protocol OctopusRemoteClient {
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
    func set(localeIdentifier: String)
}

public class GrpcClient: OctopusRemoteClient {
    public var octoService: OctoService { _octoService }
    public var magicLinkService: MagicLinkService { _magicLinkService }
    public var userService: UserService { _userService }
    public var feedService: FeedService { _feedService }
    public var trackingService: TrackingService { _trackingService }
    public var notificationService: NotificationService { _notificationService }
    public var apiKeyService: ApiKeyService { _apiKeyService }

    private let _octoService: OctoServiceClient
    private let _magicLinkService: MagicLinkServiceClient
    private let _userService: UserServiceClient
    private let _feedService: FeedServiceClient
    private let _trackingService: TrackingServiceClient
    private let _notificationService: NotificationServiceClient
    private let _apiKeyService: ApiKeyServiceClient

    private let unaryChannel: GRPCChannel
    private let group = PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)

    private let serviceClients: [ServiceClient]

    public init(apiKey: String, sdkVersion: String, installId: String, localeIdentifier: String,
                serverHost: String? = nil,
                serverPort: Int? = nil,
                getUserIdBlock: @escaping () -> String?,
                updateTokenBlock: @escaping (String) -> Void) throws {
        let resolved = GrpcClient.resolveBaseURL(
            override: serverHost.map { (host: $0, port: serverPort ?? 443) },
            infoDictionary: Bundle.main.infoDictionary
        )
        let unaryHost = GrpcClient.stripIPv6Brackets(resolved.host)

        unaryChannel = try GRPCChannelPool.with(
            configuration: GRPCChannelPool.Configuration.with(
                target: .host(unaryHost, port: resolved.port),
                transportSecurity: .tls(.makeClientConfigurationBackedByNIOSSL()),
                eventLoopGroup: group))

        _octoService = OctoServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            localeIdentifier: localeIdentifier,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _magicLinkService = MagicLinkServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            localeIdentifier: localeIdentifier,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _userService = UserServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            localeIdentifier: localeIdentifier,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _feedService = FeedServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            localeIdentifier: localeIdentifier,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _trackingService = TrackingServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            localeIdentifier: localeIdentifier,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _notificationService = NotificationServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            localeIdentifier: localeIdentifier,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)
        _apiKeyService = ApiKeyServiceClient(
            unaryChannel: unaryChannel, apiKey: apiKey, sdkVersion: sdkVersion, installId: installId,
            localeIdentifier: localeIdentifier,
            getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock)

        serviceClients = [_octoService, _magicLinkService, _userService, _feedService,
                          _trackingService, _notificationService, _apiKeyService]
    }

    /// Resolves the base URL for the unary channel.
    ///
    /// Resolution order: explicit override → Info.plist `OCTOPUS_REMOTE_BASE_URL` (internal) → default.
    static func resolveBaseURL(
        override: (host: String, port: Int)?,
        infoDictionary: [String: Any]?
    ) -> (host: String, port: Int) {
        if let override {
            return override
        }
        if let plistValue = infoDictionary?["OCTOPUS_REMOTE_BASE_URL"] as? String,
           !plistValue.isEmpty {
            return (host: plistValue, port: 443)
        }
        return (host: "api.8pus.io", port: 443)
    }

    /// Strips a surrounding `[...]` pair if present.
    static func stripIPv6Brackets(_ host: String) -> String {
        guard host.count >= 2, host.first == "[", host.last == "]" else { return host }
        return String(host.dropFirst().dropLast())
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

    public func set(localeIdentifier: String) {
        serviceClients.forEach { $0.localeIdentifier = localeIdentifier }
    }

    deinit {
        Task { [group] in
            try? await group.shutdownGracefully()
        }
    }
}
