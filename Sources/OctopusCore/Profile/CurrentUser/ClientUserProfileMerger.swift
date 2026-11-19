//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusRemoteClient
import os
import OctopusDependencyInjection
import OctopusGrpcModels

extension Injected {
    static let clientUserProfileMerger = Injector.InjectedIdentifier<ClientUserProfileMerger>()
}

class ClientUserProfileMerger: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.clientUserProfileMerger

    @UserDefault(key: "OctopusSDK.client.user.picture") private var latestClientUserPicture: Data?

    private let appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>
    private let remoteClient: OctopusRemoteClient
    private let authCallProvider: AuthenticatedCallProvider
    private let networkMonitor: NetworkMonitor
    private let gamificationRepository: GamificationRepository
    private let sdkEventsEmitter: SdkEventsEmitter

    private var latestClientUserSent: ClientUser?
    private var sameClientUserSendingCount = 0
    /// Guards `latestClientUserSent`, `sameClientUserSendingCount` and `latestClientUserPicture`: updates for
    /// different host's profiles can be sent at the same time, each in its own task.
    private let sendingStateLock = NSLock()

    /// Counts the updates started, so that a failed one restores the state only when no other one started since.
    private var sendingGeneration = 0

    /// What the merger remembers of the updates it sent, restored when one fails.
    private struct SendingState {
        let clientUser: ClientUser?
        let count: Int
        let generation: Int
    }

    /// The update being sent: the host's profile it brings, the user it is sent for, and its answer.
    private var updateInFlight: (clientUser: ClientUser, userId: String, id: UUID,
                                 task: Task<StorableCurrentUserProfile?, Error>)?
    /// Number of merges that got the answer of the update in flight rather than sending their own. Read by the tests,
    /// which keep an update in flight until another merge joins it: such a merge touches nothing else they can see.
    var joinedUpdatesCount: Int {
        updateInFlightLock.lock()
        defer { updateInFlightLock.unlock() }
        return _joinedUpdatesCount
    }
    private var _joinedUpdatesCount = 0
    private let updateInFlightLock = NSLock()

    init(appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>, injector: Injector) {
        self.appManagedFields = appManagedFields
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        gamificationRepository = injector.getInjected(identifiedBy: Injected.gamificationRepository)
        sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
    }

    func updateProfileWithClientUser(_ clientUser: ClientUser, profile: CurrentUserProfile, userId: String)
    async throws(UpdateProfile.Error) -> StorableCurrentUserProfile? {
        try await sendingOnce(clientUser, userId: userId) { [self] in
            try await updateProfileWithClientUser(
                clientUser,
                profileIsGuest: profile.isGuest,
                profileHasConfirmedNickname: profile.hasConfirmedNickname,
                profileOriginalNickname: profile.originalNickname, profileNickname: profile.nickname,
                profileHasConfirmedBio: profile.hasConfirmedBio, profileBio: profile.bio,
                profileHasConfirmedPicture: profile.hasConfirmedPicture, profilePictureUrl: profile.pictureUrl,
                userId: userId)
        }
    }

    func updateProfileWithClientUser(_ clientUser: ClientUser, profile: StorableCurrentUserProfile, userId: String)
    async throws(UpdateProfile.Error) -> StorableCurrentUserProfile? {
        try await sendingOnce(clientUser, userId: userId) { [self] in
            try await updateProfileWithClientUser(
                clientUser,
                profileIsGuest: profile.isGuest,
                profileHasConfirmedNickname: profile.hasConfirmedNickname ?? true,
                profileOriginalNickname: profile.originalNickname, profileNickname: profile.nickname,
                profileHasConfirmedBio: profile.hasConfirmedBio ?? true, profileBio: profile.bio,
                profileHasConfirmedPicture: profile.hasConfirmedPicture ?? true, profilePictureUrl: profile.pictureUrl,
                userId: userId)
        }
    }

    /// Runs `update`, unless the same host's profile is already being sent for the same user: its answer is then
    /// the one returned. The connection and the profile repository can fill the profile at the same time, as when the
    /// fetch of the profile stores its migration while the connection fills it, and the update would be sent twice.
    private func sendingOnce(_ clientUser: ClientUser, userId: String,
                             update: @escaping @Sendable () async throws -> StorableCurrentUserProfile?)
    async throws(UpdateProfile.Error) -> StorableCurrentUserProfile? {
        let task = sendingUpdate(of: clientUser, userId: userId, startingWith: update)
        do {
            return try await task.value
        } catch let error as UpdateProfile.Error {
            throw error
        } catch {
            throw .serverCall(.other(error))
        }
    }

    /// The update being sent with `clientUser` for `userId`, started with `update` when there is none.
    private func sendingUpdate(of clientUser: ClientUser, userId: String,
                               startingWith update: @escaping @Sendable () async throws -> StorableCurrentUserProfile?)
    -> Task<StorableCurrentUserProfile?, Error> {
        updateInFlightLock.lock()
        defer { updateInFlightLock.unlock() }
        if let updateInFlight, updateInFlight.clientUser == clientUser, updateInFlight.userId == userId {
            _joinedUpdatesCount += 1
            return updateInFlight.task
        }
        let id = UUID()
        let task = Task { [self] in
            // The lock is held until the update is registered, so it cannot be removed before.
            defer { removeUpdateInFlight(id: id) }
            return try await update()
        }
        updateInFlight = (clientUser, userId, id, task)
        return task
    }

    private func removeUpdateInFlight(id: UUID) {
        updateInFlightLock.lock()
        defer { updateInFlightLock.unlock() }
        if updateInFlight?.id == id { updateInFlight = nil }
    }

    func clearLatestClientUser() {
        sendingStateLock.lock()
        defer { sendingStateLock.unlock() }
        latestClientUserPicture = nil
        latestClientUserSent = nil
        sameClientUserSendingCount = 0
        // an update that fails after this must not bring back what was cleared
        sendingGeneration += 1
    }

    private func latestPictureSent() -> Data? {
        sendingStateLock.lock()
        defer { sendingStateLock.unlock() }
        return latestClientUserPicture
    }

    /// Records that `clientUser` is being sent, and returns what to restore if the update fails, or nil when the same
    /// host's profile was sent too many times in a row: the server answered each of them with a profile that differs
    /// from it, and sending it again would only loop.
    private func startSending(_ clientUser: ClientUser) -> SendingState? {
        sendingStateLock.lock()
        defer { sendingStateLock.unlock() }
        sendingGeneration += 1
        let previousState = SendingState(clientUser: latestClientUserSent, count: sameClientUserSendingCount,
                                         generation: sendingGeneration)
        if latestClientUserSent == clientUser {
            sameClientUserSendingCount += 1
            guard sameClientUserSendingCount < 3 else {
                if #available(iOS 14, *) { Logger.profile.trace("Too many attempts at using client user for the profile update") }
                return nil
            }
        } else {
            sameClientUserSendingCount = 0
        }
        latestClientUserSent = clientUser
        return previousState
    }

    /// Records the picture of `clientUser` as sent, once an update carrying it succeeded. Recorded earlier, an update
    /// started meanwhile with the same picture would leave it out, and it would never be sent if the first one fails.
    private func recordPictureSent(of clientUser: ClientUser) {
        sendingStateLock.lock()
        defer { sendingStateLock.unlock() }
        latestClientUserPicture = clientUser.profile.picture
    }

    /// Forgets the update that failed, unless another one was started since. A failed update does not
    /// count against the tries of the same host's profile: a failure changes no profile, so it cannot start a loop,
    /// and a host calling `connectUser` on each launch while the server refuses it would otherwise use them all up,
    /// leaving none for when the community opens to the user.
    private func endSendingAfterFailure(restoring previousState: SendingState) {
        sendingStateLock.lock()
        defer { sendingStateLock.unlock() }
        guard sendingGeneration == previousState.generation else { return }
        latestClientUserSent = previousState.clientUser
        sameClientUserSendingCount = previousState.count
    }

    private func updateProfileWithClientUser(
        _ clientUser: ClientUser,
        profileIsGuest: Bool,
        profileHasConfirmedNickname: Bool,
        profileOriginalNickname: String?,
        profileNickname: String,
        profileHasConfirmedBio: Bool,
        profileBio: String?,
        profileHasConfirmedPicture: Bool,
        profilePictureUrl: URL?,
        userId: String)
    async throws(UpdateProfile.Error) -> StorableCurrentUserProfile? {
        guard !profileIsGuest else { throw .serverCall(.other(InternalError.incorrectState)) }

        var hasUpdate = false
        let nickname: EditableProfile.FieldUpdate<String>
        let hasConfirmedNickname: EditableProfile.FieldUpdate<Bool>
        let findAvailableNickname: Bool
        // update the field if is appManaged or if the user has not yet confirmed it
        if appManagedFields.contains(.nickname) || !profileHasConfirmedNickname,
           let clientNickname = clientUser.profile.nickname?.nilIfEmpty,
           // check with the original nickname first because the nickname can vary from the one requested
           (profileOriginalNickname ?? profileNickname) != clientNickname {
            if profileNickname == clientNickname {
                // The host sends the variant the user ended up with: there is no nickname to send. Sending it
                // again would, when the app does not manage the nickname, ask the server to look for an available
                // one. When it does manage it, the nickname is still confirmed, but only along with another
                // change: on its own it is not worth a call.
                nickname = .unchanged
                hasConfirmedNickname = appManagedFields.contains(.nickname) && !profileHasConfirmedNickname
                    ? .updated(true) : .unchanged
                findAvailableNickname = false
            } else {
                if #available(iOS 14, *) { Logger.profile.trace("Nickname changed (old: \(profileNickname), new: \(clientNickname))") }
                nickname = .updated(clientNickname)
                hasConfirmedNickname = appManagedFields.contains(.nickname) ? .updated(true) : .unchanged
                findAvailableNickname = !appManagedFields.contains(.nickname)
                hasUpdate = true
            }
        } else {
            nickname = .unchanged
            hasConfirmedNickname = .unchanged
            findAvailableNickname = false
        }

        let bio: EditableProfile.FieldUpdate<String?>
        let hasConfirmedBio: EditableProfile.FieldUpdate<Bool>
        if appManagedFields.contains(.bio) || !profileHasConfirmedBio,
           profileBio?.nilIfEmpty != clientUser.profile.bio?.nilIfEmpty {
            if #available(iOS 14, *) { Logger.profile.trace("Bio changed (old: \(profileBio ?? "nil"), new: \(clientUser.profile.bio ?? "nil"))") }
            bio = .updated(clientUser.profile.bio)
            hasConfirmedBio = appManagedFields.contains(.bio) ? .updated(true) : .unchanged
            hasUpdate = true
        } else {
            bio = .unchanged
            hasConfirmedBio = .unchanged
        }

        let picture: EditableProfile.FieldUpdate<Data?>
        let hasConfirmedPicture: EditableProfile.FieldUpdate<Bool>
        if appManagedFields.contains(.picture) || !profileHasConfirmedPicture,
           latestPictureSent() != clientUser.profile.picture,
           clientUser.profile.picture != nil || profilePictureUrl != nil {
            if #available(iOS 14, *) { Logger.profile.trace("Picture changed") }
            picture = .updated(clientUser.profile.picture)
            hasConfirmedPicture = appManagedFields.contains(.picture) ? .updated(true) : .unchanged
            hasUpdate = true
        } else {
            picture = .unchanged
            hasConfirmedPicture = .unchanged
        }

        guard hasUpdate else { return nil }
        guard networkMonitor.connectionAvailable else { throw .serverCall(.noNetwork) }

        // avoid sending in loop the same client user updates
        guard let previousSendingState = startSending(clientUser) else { return nil }

        do {
            var pictureUpdate: EditableProfile.FieldUpdate<(imgData: Data, isCompressed: Bool)?> = .unchanged
            if case let .updated(imageData) = picture {
                if let imageData {
                    let (resizedImgData, isCompressed) = ImageResizer.resizeIfNeeded(imageData: imageData)
                    pictureUpdate = .updated((imgData: resizedImgData, isCompressed: isCompressed))
                } else {
                    pictureUpdate = .updated(nil)
                }
            }
            let response = try await remoteClient.userService.updateProfile(
                userId: userId,
                profile: .init(
                    nickname: nickname.backendValue,
                    bio: bio.backendValue,
                    picture: pictureUpdate.backendValue,
                    hasConfirmedNickname: hasConfirmedNickname.backendValue,
                    hasConfirmedBio: hasConfirmedBio.backendValue,
                    hasConfirmedPicture: hasConfirmedPicture.backendValue,
                    optFindAvailableNickname: findAvailableNickname
                ),
                authenticationMethod: try authCallProvider.authenticatedMethod())
            switch response.result {
            case let .success(content):
                if content.hasShouldDisplayProfileCompletedGamificationToast,
                   content.shouldDisplayProfileCompletedGamificationToast {
                    gamificationRepository.register(action: .profileCompleted)
                }

                if case .updated = picture {
                    recordPictureSent(of: clientUser)
                }
                sdkEventsEmitter.emit(.profileUpdated)

                return StorableCurrentUserProfile(from: content.profile, userId: userId)

            case let .fail(failure):
                throw UpdateProfile.Error.validation(.init(from: failure))
            case .none:
                throw UpdateProfile.Error.serverCall(.other(nil))
            }
        } catch {
            endSendingAfterFailure(restoring: previousSendingState)
            if #available(iOS 14, *) { Logger.profile.debug("Error syncing profile: \(error)") }
            if let error = error as? UpdateProfile.Error {
                throw error
            } else if let error = error as? AuthenticatedActionError {
                throw .serverCall(error)
            } else if let error = error as? RemoteClientError {
                throw .serverCall(.serverError(ServerError(remoteClientError: error)))
            } else {
                throw .serverCall(.other(error))
            }
        }
    }
}
