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
        try await updateProfileWithClientUser(
            clientUser,
            profileIsGuest: profile.isGuest,
            profileHasConfirmedNickname: profile.hasConfirmedNickname,
            profileOriginalNickname: profile.originalNickname, profileNickname: profile.nickname,
            profileHasConfirmedBio: profile.hasConfirmedBio, profileBio: profile.bio,
            profileHasConfirmedPicture: profile.hasConfirmedPicture, profilePictureUrl: profile.pictureUrl,
            userId: userId)
    }

    func updateProfileWithClientUser(_ clientUser: ClientUser, profile: StorableCurrentUserProfile, userId: String)
    async throws(UpdateProfile.Error) -> StorableCurrentUserProfile? {
        try await updateProfileWithClientUser(
            clientUser,
            profileIsGuest: profile.isGuest,
            profileHasConfirmedNickname: profile.hasConfirmedNickname ?? true,
            profileOriginalNickname: profile.originalNickname, profileNickname: profile.nickname,
            profileHasConfirmedBio: profile.hasConfirmedBio ?? true, profileBio: profile.bio,
            profileHasConfirmedPicture: profile.hasConfirmedPicture ?? true, profilePictureUrl: profile.pictureUrl,
            userId: userId)
    }

    func clearLatestClientUser() {
        latestClientUserPicture = nil
        latestClientUserSent = nil
        sameClientUserSendingCount = 0
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
        if (appManagedFields.contains(.nickname) || !profileHasConfirmedNickname),
           let clientNickname = clientUser.profile.nickname?.nilIfEmpty,
           // check with the original nickname first because the nickname can vary from the one requested
           (profileOriginalNickname ?? profileNickname) != clientNickname {
            if #available(iOS 14, *) { Logger.profile.trace("Nickname changed (old: \(profileNickname), new: \(clientNickname))") }
            nickname = .updated(clientNickname)
            hasConfirmedNickname = appManagedFields.contains(.nickname) ? .updated(true) : .unchanged
            findAvailableNickname = !appManagedFields.contains(.nickname)
            hasUpdate = true
        } else {
            nickname = .unchanged
            hasConfirmedNickname = .unchanged
            findAvailableNickname = false
        }

        let bio: EditableProfile.FieldUpdate<String?>
        let hasConfirmedBio: EditableProfile.FieldUpdate<Bool>
        if (appManagedFields.contains(.bio) || !profileHasConfirmedBio),
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
        if (appManagedFields.contains(.picture) || !profileHasConfirmedPicture),
           latestClientUserPicture != clientUser.profile.picture,
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
        if latestClientUserSent == clientUser {
            sameClientUserSendingCount += 1
            guard sameClientUserSendingCount < 3 else {
                if #available(iOS 14, *) { Logger.profile.trace("Too many attempts at using client user for the profile update") }
                return nil
            }
        } else {
            sameClientUserSendingCount = 0
        }

        let previousClientUserPicture = latestClientUserPicture
        do {
            latestClientUserSent = clientUser
            latestClientUserPicture = clientUser.profile.picture
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

                sdkEventsEmitter.emit(.profileUpdated)

                return StorableCurrentUserProfile(from: content.profile, userId: userId)

            case let .fail(failure):
                throw UpdateProfile.Error.validation(.init(from: failure))
            case .none:
                throw UpdateProfile.Error.serverCall(.other(nil))
            }
        } catch {
            // rollback client picture hash
            latestClientUserPicture = previousClientUserPicture
            if #available(iOS 14, *) { Logger.profile.debug("Error syncing profile: \(error)") }
            return nil
        }
    }
}
