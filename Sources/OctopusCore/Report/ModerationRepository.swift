//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusRemoteClient
import OctopusDependencyInjection
import OctopusGrpcModels

extension Injected {
    static let moderationRepository = Injector.InjectedIdentifier<ModerationRepository>()
}

public class ModerationRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.moderationRepository

    private let remoteClient: OctopusRemoteClient
    private let authCallProvider: AuthenticatedCallProvider
    private let networkMonitor: NetworkMonitor

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
    }

    public func reportContent(contentId: String, reasons: [ReportReason]) async throws(AuthenticatedActionError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            _ = try await remoteClient.octoService.reportContent(
                objectId: contentId,
                reasons: reasons.map { $0.protoValue },
                authenticationMethod: try authCallProvider.authenticatedMethod())
        } catch {
            if let error = error as? AuthenticatedActionError {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    public func reportUser(profileId: String, reasons: [ReportReason]) async throws(AuthenticatedActionError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            _ = try await remoteClient.userService.reportUser(
                profileId: profileId,
                reasons: reasons.map { $0.protoValue },
                authenticationMethod: try authCallProvider.authenticatedMethod())
        } catch {
            if let error = error as? AuthenticatedActionError {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }
}
