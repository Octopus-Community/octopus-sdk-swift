//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import os
import OctopusRemoteClient
import OctopusDependencyInjection

protocol AuthenticatedCallProvider {
    func authenticatedMethod() throws(AuthenticatedActionError) -> AuthenticationMethod
    func authenticatedMethod(forceJwt: String) throws(AuthenticatedActionError) -> AuthenticationMethod
    func authenticatedIfPossibleMethod() -> AuthenticationMethod
    /// The user of the current session, guest or member, `nil` when there is none. A response refused because the
    /// session changed during its call is one sent with another value than the current one.
    var sessionUserId: String? { get }
}

extension Injected {
    static let authenticatedCallProvider = Injector.InjectedIdentifier<AuthenticatedCallProvider>()
}

class AuthenticatedCallProviderDefault: AuthenticatedCallProvider, InjectableObject {
    static let injectedIdentifier = Injected.authenticatedCallProvider

    private weak var injector: Injector?
    private let userDataStorage: UserDataStorage
    private lazy var connectionRepository: ConnectionRepository? = {
        injector?.getInjected(identifiedBy: Injected.connectionRepository)
    }()

    init(injector: Injector) {
        self.injector = injector
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
    }

    var sessionUserId: String? { userDataStorage.userData?.id }

    func authenticatedMethod() throws(AuthenticatedActionError) -> AuthenticationMethod {
        guard let userData = userDataStorage.userData else {
            throw .userNotAuthenticated
        }
        return try authenticatedMethod(forceJwt: userData.jwtToken)
    }

    func authenticatedMethod(forceJwt: String) throws(AuthenticatedActionError) -> AuthenticationMethod {
        return .authenticated(
            token: forceJwt,
            authFailure: { [weak self] in
                guard let self else { return }
                if #available(iOS 14, *) { Logger.connection.debug("Authentication error received from server, logging out the user") }
                let connectionRepository = self.connectionRepository
                Task {
                    do {
                        try await connectionRepository?.onAuthenticatedCallFailed()
                    } catch {
                        if #available(iOS 14, *) {
                            Logger.connection.debug("Error while handling an authenticated call failure: \(error)")
                        }
                    }
                }
            })
    }

    func authenticatedIfPossibleMethod() -> AuthenticationMethod {
        guard let userData = userDataStorage.userData else {
            return .notAuthenticated
        }
        return .authenticated(
            token: userData.jwtToken,
            authFailure: { [weak self] in
                guard let self else { return }
                if #available(iOS 14, *) { Logger.connection.debug("Authentication error received from server, logging out the user") }
                let connectionRepository = self.connectionRepository
                Task {
                    do {
                        try await connectionRepository?.onAuthenticatedCallFailed()
                    } catch {
                        if #available(iOS 14, *) {
                            Logger.connection.debug("Error while handling an authenticated call failure: \(error)")
                        }
                    }
                }
            })
    }
}

extension AuthenticatedCallProvider {
    /// Sends a read that a guest can make as well as a member, with the session of the moment.
    ///
    /// A response that comes back after the session changed is refused, so that it is never taken for the new
    /// session's. Signing a member in, or switching community, moves the session through several states in a row
    /// (none, guest, member), and the screens that load meanwhile would show an error for a read that only had to be
    /// sent again: it is, with the session that is current then, as long as the session keeps changing, up to
    /// `maxSessionChangeReplays` times. Only reads go through it: a write is never sent again on behalf of another
    /// session, nor is a page read from a cursor that was handed to the previous session.
    ///
    /// - Parameter call: the remote client call, made with the authentication it is given. It only throws
    ///   `RemoteClientError`s, but its type keeps a plain `throws`: a typed throws in a function type crashes below
    ///   iOS 18 as soon as the type is reflected.
    func withAuthenticatedIfPossibleMethod<T>(_ call: (AuthenticationMethod) async throws -> T)
    async throws(RemoteClientError) -> T {
        try await withAuthenticatedIfPossibleMethod { authenticationMethod, _ in try await call(authenticationMethod) }
    }

    /// Same as `withAuthenticatedIfPossibleMethod(_:)`, for a read with a side effect on the server, such as counting
    /// a view: the refused response was still handled by the server, so a replay must not repeat that effect.
    ///
    /// - Parameter call: the remote client call, made with the authentication it is given, and told whether it is a
    ///   replay of a call whose response was refused.
    func withAuthenticatedIfPossibleMethod<T>(_ call: (AuthenticationMethod, _ isReplay: Bool) async throws -> T)
    async throws(RemoteClientError) -> T {
        var replays = 0
        while true {
            do {
                return try await call(authenticatedIfPossibleMethod(), replays > 0)
            } catch {
                let error = error as? RemoteClientError ?? .unknown(error)
                // A cancelled read is not sent again: nobody waits for its response anymore.
                guard error.isSessionChangedDuringCall, replays < maxSessionChangeReplays, !Task.isCancelled else {
                    throw error
                }
                replays += 1
                if #available(iOS 14, *) { Logger.connection.debug("Session changed during a read, sending it again") }
            }
        }
    }
}

/// The most changes a session goes through in a row: a member switching community is signed out, then a guest, then
/// signed in again (member, none, guest, member).
let maxSessionChangeReplays = 3
