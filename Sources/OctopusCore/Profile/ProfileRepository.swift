//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusRemoteClient
import os
import OctopusDependencyInjection
import OctopusGrpcModels

public protocol ProfileRepository: Sendable {
    var profile: CurrentUserProfile? { get }
    var profilePublisher: AnyPublisher<CurrentUserProfile?, Never> { get }

    var hasLoadedProfile: Bool { get }
    var hasLoadedProfilePublisher: AnyPublisher<Bool, Never> { get }

    var onCurrentUserProfileUpdated: AnyPublisher<Void, Never> { get }

    /// Emits the result of each profile sync attempt triggered by the Combine pipeline.
    var profileSyncResultPublisher: AnyPublisher<Result<Void, UpdateProfile.Error>, Never> { get }

    func fetchCurrentUserProfile() async throws(AuthenticatedActionError)

//    @discardableResult
//    func createCurrentUserProfile(with profile: EditableProfile) async throws(UpdateProfile.Error)
//    -> (CurrentUserProfile, Data?)

    @discardableResult
    func updateCurrentUserProfile(with profile: EditableProfile) async throws(UpdateProfile.Error)
    -> (CurrentUserProfile, Data?)

    func deleteCurrentUserProfile(profileId: String) async throws
    func resetNotificationBadgeCount() async throws

    func getProfile(profileId: String) -> AnyPublisher<Profile?, Never>
    func fetchProfile(profileId: String) async throws(ServerCallError)

    /// Fetches a member's public profile directly by their Octopus profile id (Unified Profile).
    /// Mirrors ``fetchProfile(byClientUserId:)`` but resolves the member by their Octopus id rather
    /// than the host's own client user id, so it needs no client-user-id lookup. Upserts the fetched
    /// profile into the public-profile database when one is returned, and returns the profile as cached
    /// (or `nil` when the server has no such profile): its level and total points may come from a newer
    /// request than this one (see `ProfileGamificationOrder`). Unlike ``fetchProfile(profileId:)`` — which
    /// only refreshes the cache and returns `Void` — this returns the profile for a one-shot read.
    func fetchProfile(byProfileId profileId: String) async throws(ServerCallError) -> Profile?

    /// Fetches a member's public profile by the host's own client user id (Unified Profile), resolved
    /// through the `GetPublicProfile` client-user-id lookup. Upserts the fetched profile into the
    /// public-profile database when one is returned, and returns the profile as cached, as
    /// ``fetchProfile(byProfileId:)`` does (or `nil` when the community has no member for that client
    /// user id). An empty response leaves the cache untouched — there is
    /// nothing cached under a client user id to evict. The lookup may fail with a server error (e.g.
    /// FAILED_PRECONDITION) when the community does not expose client user ids.
    func fetchProfile(byClientUserId clientUserId: String) async throws(ServerCallError) -> Profile?

    func blockUser(profileId: String) async throws(AuthenticatedActionError)
}

extension Injected {
    static let profileRepository = Injector.InjectedIdentifier<ProfileRepository>()
}

class ProfileRepositoryDefault: ProfileRepository, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.profileRepository

    @Published public private(set) var profile: CurrentUserProfile?
    var profilePublisher: AnyPublisher<CurrentUserProfile?, Never> { $profile.eraseToAnyPublisher() }
    @Published private(set) var hasLoadedProfile: Bool = false
    var hasLoadedProfilePublisher: AnyPublisher<Bool, Never> { $hasLoadedProfile.eraseToAnyPublisher() }

    public var onCurrentUserProfileUpdated: AnyPublisher<Void, Never> {
        _onCurrentUserProfileUpdated.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    private let _onCurrentUserProfileUpdated = PassthroughSubject<Void, Never>()

    var profileSyncResultPublisher: AnyPublisher<Result<Void, UpdateProfile.Error>, Never> {
        _profileSyncResult.eraseToAnyPublisher()
    }
    private let _profileSyncResult = PassthroughSubject<Result<Void, UpdateProfile.Error>, Never>()

    private var profileClientUserId: String?

    private let appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>
    private let remoteClient: OctopusRemoteClient
    private let userDataStorage: UserDataStorage
    private let authCallProvider: AuthenticatedCallProvider
    private let userProfileDatabase: CurrentUserProfileDatabase
    private let publicProfileDatabase: PublicProfileDatabase
    private let networkMonitor: NetworkMonitor
    private let userProfileFetchMonitor: UserProfileFetchMonitor
    private let validator: Validators.CurrentUserProfile
    private let postFeedsStore: PostFeedsStore
    private let clientUserProvider: ClientUserProvider
    private let configRepository: ConfigRepository
    private let gamificationRepository: GamificationRepository
    private let sdkEventsEmitter: SdkEventsEmitter
    private let clientUserProfileMerger: ClientUserProfileMerger
    private let frictionlessProfileMigrator: FrictionlessProfileMigrator
    private var storage: Set<AnyCancellable> = []

    init(appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>, injector: Injector) {
        self.appManagedFields = appManagedFields
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
        publicProfileDatabase = injector.getInjected(identifiedBy: Injected.publicProfileDatabase)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        userProfileFetchMonitor = injector.getInjected(identifiedBy: Injected.userProfileFetchMonitor)
        validator = injector.getInjected(identifiedBy: Injected.validators).currentUserProfile
        postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)
        clientUserProvider = injector.getInjected(identifiedBy: Injected.clientUserProvider)
        configRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        gamificationRepository = injector.getInjected(identifiedBy: Injected.gamificationRepository)
        sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
        clientUserProfileMerger = injector.getInjected(identifiedBy: Injected.clientUserProfileMerger)
        frictionlessProfileMigrator = injector.getInjected(identifiedBy: Injected.frictionlessProfileMigrator)
        // See `PublishedPublishers`: done before anything can write these values.
        PublishedPublishers.create($profile, $hasLoadedProfile)

        userDataStorage.$userData
            .receive(on: DispatchQueue.main)
            .map { [weak self] userData in
                guard let self, let userData else {
                    return Just<(CurrentUserProfile, String?)?>(nil).eraseToAnyPublisher()
                }
                return Publishers.CombineLatest(
                    userProfileDatabase.profilePublisher(userId: userData.id),
                    configRepository.communityConfigPublisher.map { $0?.gamificationConfig?.gamificationLevels }
                        .removeDuplicates()
                )
                .map { [weak self] in
                    guard let self, let storableProfile = $0 else { return nil }
                    // Unified Profile (SSO): stamp the host's client user id on the connected user's
                    // profile. Mirrors Android — only non-guest profiles carry it; guests get nil.
                    // (The tuple's second element stays the raw clientId, feeding profileClientUserId
                    // for the client-user/profile matching below.)
                    let clientUserId = storableProfile.isGuest ? nil : userData.clientId
                    return (CurrentUserProfile(storableProfile: storableProfile, gamificationLevels: $1 ?? [],
                                               postFeedsStore: postFeedsStore, clientUserId: clientUserId),
                            userData.clientId)
                }
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .removeDuplicates(by: {
                let profile1 = $0?.0
                let profile2 = $1?.0
                let clientId1 = $0?.1
                let clientId2 = $1?.1
                return profile1 == profile2 && clientId1 == clientId2
            })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                let profile = $0?.0
                let clientUserId = $0?.1
                profileClientUserId = clientUserId
                self.profile = profile
                hasLoadedProfile = true
            }.store(in: &storage)

        userProfileFetchMonitor.orderedUserProfileResponsePublisher
            // Each response once, as soon as the community is open to the user. Taken again on a later opening, it
            // would be the profile as it was then, maybe of a session that is gone: migrated again, a profile without
            // a nickname would lose what its member confirmed since.
            .map { [configRepository] response, userId, gamificationTicket in
                configRepository.userConfigPublisher
                    .first { $0?.canAccessCommunity ?? false }
                    .map { _ in (response, userId, gamificationTicket) }
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response, userId, gamificationTicket in
                guard let self,
                      // the session it was fetched for is gone
                      userDataStorage.userData?.id == userId else { return }
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await processCurrentUserProfileResponse(response, userId: userId,
                                                                    gamificationTicket: gamificationTicket)
                    } catch {
                        if #available(iOS 14, *) {
                            Logger.profile.debug("Error while processing user profile response: \(error)")
                        }
                    }
                }
            }
            .store(in: &storage)

        Publishers.CombineLatest4(
            $profile.removeDuplicates(),
            clientUserProvider.$clientUser,
            networkMonitor.connectionAvailablePublisher,
            // Not filtered on an open community: the last opening would let profiles through once it closes. The
            // server refuses them then, and each refusal uses up one of the tries the merger allows the same update.
            configRepository.userConfigPublisher.map { $0?.canAccessCommunity ?? false }.removeDuplicates()
        )
        .sink { [weak self] profile, clientUser, connectionAvailable, canAccessCommunity in
            guard let self,
                  connectionAvailable,
                  canAccessCommunity,
                  let profile,
                  let clientUser,
                  // ensure the client user is matching the current profile
                  // if profileClientUserId is nil, consider that it is the same profile,
                  // just in case there is a version where the client id was not stored
                  clientUser.userId == (profileClientUserId ?? clientUser.userId),
                  !profile.isGuest,
                  // Filled before its migration to a frictionless profile, a profile would be migrated wrongly or
                  // never: a nickname makes the migration take it for a complete one and confirm the terms, and a
                  // confirmed nickname, which an app-managed one is, makes it look already migrated. The migration
                  // stores the profile again, and it is filled then.
                  !profile.isFrictionlessMigrationPending else { return }
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await updateProfileWithClientUser(clientUser, profile: profile)
                    _profileSyncResult.send(.success(()))
                } catch let error as UpdateProfile.Error {
                    _profileSyncResult.send(.failure(error))
                } catch {
                    _profileSyncResult.send(.failure(.other(error)))
                }
            }
        }.store(in: &storage)
    }

    // MARK: Current User APIs

    public func fetchCurrentUserProfile() async throws(AuthenticatedActionError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        guard let userData = userDataStorage.userData else {
            throw .userNotAuthenticated
        }
        do {
            let (profileResponse, gamificationTicket) = try await ProfileGamificationOrder.send {
                try await remoteClient.userService.getPrivateProfile(
                    userId: userData.id, authenticationMethod: try authCallProvider.authenticatedMethod())
            }
            try await processCurrentUserProfileResponse(profileResponse, userId: userData.id,
                                                        gamificationTicket: gamificationTicket)
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

    @discardableResult
    public func updateCurrentUserProfile(with profile: EditableProfile)
    async throws(UpdateProfile.Error) -> (CurrentUserProfile, Data?) {
        let value = try await createOrUpdateUserProfile(with: profile)
        sdkEventsEmitter.emit(.profileModified(.init(profile: profile)))
        return value
    }

    func deleteCurrentUserProfile(profileId: String) async throws {
        try await userProfileDatabase.delete(profileId: profileId)
    }

    func resetNotificationBadgeCount() async throws {
        guard let profile else { throw InternalError.incorrectState }
        try await userProfileDatabase.resetNotificationBadgeCount(on: profile.id)
    }

    // MARK: Other users APIs

    public func getProfile(profileId: String) -> AnyPublisher<Profile?, Never> {
        Publishers.CombineLatest(
            publicProfileDatabase.profilePublisher(profileId: profileId),
            configRepository.communityConfigPublisher.map { $0?.gamificationConfig?.gamificationLevels }
                .removeDuplicates()
        )
        .map { [unowned self] profile, gamificationLevels in
            guard let profile else { return nil }
            return Profile(storableProfile: profile,
                           gamificationLevels: gamificationLevels ?? [],
                           postFeedsStore: postFeedsStore)
        }
        .eraseToAnyPublisher()
    }

    public func fetchProfile(profileId: String) async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            // The ticket is taken inside the closure, which is called again for a replay.
            let (profileResponse, gamificationTicket) = try await authCallProvider
                .withAuthenticatedIfPossibleMethod { authenticationMethod in
                try await ProfileGamificationOrder.send {
                    try await remoteClient.userService.getPublicProfile(
                        profileId: profileId,
                        authenticationMethod: authenticationMethod)
                }
            }
            try await publicProfileDatabase.upsert(profile: StorableProfile(from: profileResponse.profile),
                                                   gamificationTicket: gamificationTicket)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    public func fetchProfile(byProfileId profileId: String) async throws(ServerCallError) -> Profile? {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        // Cold start: the gamification level is resolved against the cached community config. Without
        // this best-effort load, a fetch performed before the config is cached would report
        // `gamificationLevel == nil` even when gamification is enabled (indistinguishable from
        // "disabled"). A config failure falls back to the previous behavior instead of failing the
        // profile fetch itself.
        if configRepository.communityConfig == nil {
            try? await configRepository.refreshCommunityConfig()
        }
        do {
            // The ticket is taken inside the closure, which is called again for a replay.
            let (profileResponse, gamificationTicket) = try await authCallProvider
                .withAuthenticatedIfPossibleMethod { authenticationMethod in
                try await ProfileGamificationOrder.send {
                    try await remoteClient.userService.getPublicProfile(
                        profileId: profileId,
                        authenticationMethod: authenticationMethod)
                }
            }
            // Mirror fetchProfile(byClientUserId:): return nil on an empty response rather than
            // upserting a malformed profile.
            guard profileResponse.hasProfile else { return nil }
            // The cached profile, not the response: its total may come from a newer request, and the community data
            // returned here must match the one the publishers show.
            let cachedProfile = try await publicProfileDatabase.upsert(
                profile: StorableProfile(from: profileResponse.profile), gamificationTicket: gamificationTicket)
            return Profile(
                storableProfile: cachedProfile,
                gamificationLevels: configRepository.communityConfig?.gamificationConfig?.gamificationLevels ?? [],
                postFeedsStore: postFeedsStore)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    public func fetchProfile(byClientUserId clientUserId: String) async throws(ServerCallError) -> Profile? {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        // Same cold-start guard as fetchProfile(byProfileId:) — see the comment there.
        if configRepository.communityConfig == nil {
            try? await configRepository.refreshCommunityConfig()
        }
        do {
            // The ticket is taken inside the closure, which is called again for a replay.
            let (profileResponse, gamificationTicket) = try await authCallProvider
                .withAuthenticatedIfPossibleMethod { authenticationMethod in
                try await ProfileGamificationOrder.send {
                    try await remoteClient.userService.getPublicProfile(
                        clientUserId: clientUserId,
                        authenticationMethod: authenticationMethod)
                }
            }
            // Unlike fetchProfile(profileId:), do NOT delete on an empty response: a community that does
            // not expose client user ids simply yields no profile, and there is nothing cached under a
            // client user id to evict.
            guard profileResponse.hasProfile else { return nil }
            // The cached profile, as in fetchProfile(byProfileId:).
            let cachedProfile = try await publicProfileDatabase.upsert(
                profile: StorableProfile(from: profileResponse.profile), gamificationTicket: gamificationTicket)
            return Profile(
                storableProfile: cachedProfile,
                gamificationLevels: configRepository.communityConfig?.gamificationConfig?.gamificationLevels ?? [],
                postFeedsStore: postFeedsStore)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    public func blockUser(profileId: String) async throws(AuthenticatedActionError) {
        guard let profile = profile else { throw .userNotAuthenticated }
        guard profileId != profile.id else { throw .other(InternalError.invalidArgument) }
        // Refuse to block admin-tagged profiles (UI hides the entry, this is the safety net).
        if let target = try? await publicProfileDatabase.getProfile(profileId: profileId),
           target.tags.contains(.admin) {
            throw .other(InternalError.invalidArgument)
        }
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            _ = try await remoteClient.userService.blockUser(
                profileId: profileId,
                authenticationMethod: try authCallProvider.authenticatedMethod())

            var existingBlockedIds = profile.blockedProfileIds
            existingBlockedIds.append(profileId)
            try await userProfileDatabase.update(blockedProfileIds: existingBlockedIds, on: profile.id)
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

    // TODO Djavan: rename updateUserProfile
    @discardableResult
    func createOrUpdateUserProfile(with profile: EditableProfile, findAvailableNickname: Bool = false)
    async throws(UpdateProfile.Error) -> (CurrentUserProfile, Data?) {
        let (storableProfile, pictureData) = try await internalUpdateUserProfile(with: profile)
        // Keep the returned value consistent with the published profile (see Combine pipeline): the
        // connected user's client user id is stamped for non-guest SSO profiles, nil otherwise.
        let clientUserId = storableProfile.isGuest ? nil : userDataStorage.userData?.clientId
        return (
            CurrentUserProfile(
                storableProfile: storableProfile,
                gamificationLevels: configRepository.communityConfig?.gamificationConfig?.gamificationLevels ?? [],
                postFeedsStore: postFeedsStore, clientUserId: clientUserId),
            pictureData)
    }

    /// - Parameter gamificationTicket: taken when the request of `response` was sent (see `ProfileGamificationOrder`).
    private func processCurrentUserProfileResponse(_ response: Com_Octopuscommunity_GetPrivateProfileResponse,
                                                   userId: String,
                                                   gamificationTicket: ProfileGamificationOrder.Ticket) async throws {
        guard response.hasProfile else { throw InternalError.objectMalformed }
        let profile = try await frictionlessProfileMigrator.migrateUserToFrictionlessUserIfNeeded(
            profile: response.profile, userId: userId)
        try await userProfileDatabase.upsert(profile: profile)
        // Keeps the member's own community data (level and total points) current without a fetch of their public
        // profile, which is what a host reads it from. A profile tagged admin carries no gamification on its public
        // profile, so nil is written for it, and a level cached for it is cleared.
        let isAdmin = profile.tags.contains(.admin)
        do {
            try await publicProfileDatabase.updateGamificationOfGamifiedProfile(
                profileId: profile.id,
                level: isAdmin ? nil : profile.gamificationLevel,
                score: isAdmin ? nil : profile.gamificationScore,
                gamificationTicket: gamificationTicket)
        } catch {
            if #available(iOS 14, *) {
                Logger.profile.debug("Error while updating the gamification of the public profile: \(error)")
            }
        }
    }

    func internalUpdateUserProfile(with profile: EditableProfile, findAvailableNickname: Bool = false)
    async throws(UpdateProfile.Error) -> (StorableCurrentUserProfile, Data?) {
        guard validator.validate(profile: profile, isGuest: self.profile?.isGuest ?? true) else {
            throw .serverCall(.other(InternalError.objectMalformed))
        }
        // this function can be called when we are not yet fully connected, so we do not use the user but the userData
        guard let userData = userDataStorage.userData else {
            throw .serverCall(.userNotAuthenticated)
        }
        guard networkMonitor.connectionAvailable else { throw .serverCall(.noNetwork) }
        do {
            var resizedPicture: Data?
            var pictureUpdate: EditableProfile.FieldUpdate<(imgData: Data, isCompressed: Bool)?> = .unchanged
            if case let .updated(imageData) = profile.picture {
                if let imageData {
                    let (resizedImgData, isCompressed) = ImageResizer.resizeIfNeeded(imageData: imageData)
                    resizedPicture = resizedImgData
                    pictureUpdate = .updated((imgData: resizedImgData, isCompressed: isCompressed))
                } else {
                    pictureUpdate = .updated(nil)
                }
            }
            let response = try await remoteClient.userService.updateProfile(
                userId: userData.id,
                profile: .init(
                    nickname: profile.nickname.backendValue,
                    bio: profile.bio.backendValue,
                    picture: pictureUpdate.backendValue,
                    hasSeenOnboarding: profile.hasSeenOnboarding.backendValue,
                    hasAcceptedCgu: profile.hasAcceptedCgu.backendValue,
                    hasConfirmedNickname: profile.hasConfirmedNickname.backendValue,
                    hasConfirmedBio: profile.hasConfirmedBio.backendValue,
                    hasConfirmedPicture: profile.hasConfirmedPicture.backendValue,
                    optFindAvailableNickname: findAvailableNickname,
                    wantNicknameSuggestions: profile.wantNicknameSuggestions
                ),
                authenticationMethod: try authCallProvider.authenticatedMethod())
            switch response.result {
            case let .success(content):
                let profile = StorableCurrentUserProfile(from: content.profile, userId: userData.id)
                try await userProfileDatabase.upsert(profile: profile)
                _onCurrentUserProfileUpdated.send()
                if content.hasShouldDisplayProfileCompletedGamificationToast,
                   content.shouldDisplayProfileCompletedGamificationToast {
                    gamificationRepository.register(action: .profileCompleted)
                }

                sdkEventsEmitter.emit(.profileUpdated)

                return (profile, resizedPicture)

            case let .fail(failure):
                throw UpdateProfile.Error.validation(.init(from: failure))
            case .none:
                throw UpdateProfile.Error.serverCall(.other(nil))
            }
        } catch {
            if #available(iOS 14, *) { Logger.profile.debug("update profile failed with error: \(error)") }
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

    func updateProfileWithClientUser(_ clientUser: ClientUser, profile: CurrentUserProfile)
    async throws(UpdateProfile.Error) {
        guard let userData = userDataStorage.userData else { throw .serverCall(.userNotAuthenticated) }
        if let updatedProfile = try await clientUserProfileMerger.updateProfileWithClientUser(
            clientUser, profile: profile, userId: userData.id) {
            do {
                try await userProfileDatabase.upsert(profile: updatedProfile)
            } catch {
                throw .serverCall(.other(error))
            }
            _onCurrentUserProfileUpdated.send()
        }
    }
}
