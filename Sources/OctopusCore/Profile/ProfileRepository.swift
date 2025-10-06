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

    func fetchCurrentUserProfile() async throws(AuthenticatedActionError)

//    @discardableResult
//    func createCurrentUserProfile(with profile: EditableProfile) async throws(UpdateProfile.Error)
//    -> (CurrentUserProfile, Data?)

    @discardableResult
    func updateCurrentUserProfile(with profile: EditableProfile) async throws(UpdateProfile.Error)
    -> (CurrentUserProfile, Data?)

    func deleteCurrentUserProfile(profileId: String) async throws
    func resetNotificationBadgeCount() async throws

    func getProfile(profileId: String) -> AnyPublisher<Profile?, Error>
    func fetchProfile(profileId: String) async throws(ServerCallError)
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

    @UserDefault(key: "OctopusSDK.client.user.picture") private var latestClientUserPicture: Data?

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

        userDataStorage.$userData
            .receive(on: DispatchQueue.main)
            .map { [unowned self] userData in
                guard let userData else {
                    return Just<CurrentUserProfile?>(nil).eraseToAnyPublisher()
                }
                return userProfileDatabase.profilePublisher(userId: userData.id)
                    .replaceError(with: nil)
                    .map { [unowned self] in
                        guard let storableProfile = $0 else { return nil }
                        return CurrentUserProfile(storableProfile: storableProfile, postFeedsStore: postFeedsStore)
                    }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                self.profile = $0
                hasLoadedProfile = true
            }.store(in: &storage)

        Publishers.CombineLatest(
            userProfileFetchMonitor.userProfileResponsePublisher,
            configRepository.userConfigPublisher.map { $0?.canAccessCommunity ?? false }.removeDuplicates().filter { $0 }
        )
        .map { ($0.0, $0.1, $1) }
        .receive(on: DispatchQueue.main)
        .sink { [unowned self] response, userId, _ in
            Task {
                do {
                    try await processCurrentUserProfileResponse(response, userId: userId)
                } catch {
                    if #available(iOS 14, *) { Logger.profile.debug("Error while processing user profile response: \(error)") }
                }
            }
        }
        .store(in: &storage)

        Publishers.CombineLatest4(
            $profile.removeDuplicates(),
            clientUserProvider.$clientUser,
            networkMonitor.connectionAvailablePublisher,
            configRepository.userConfigPublisher.map { $0?.canAccessCommunity ?? false }.removeDuplicates().filter { $0 }
        )
        .sink { [unowned self] profile, clientUser, connectionAvailable, _ in
            guard connectionAvailable, let profile, let clientUser, !profile.isGuest else { return }
            Task {
                try await updateProfileWithClientUser(clientUser, profile: profile)
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
            let profileResponse = try await remoteClient.userService.getPrivateProfile(
                userId: userData.id, authenticationMethod: try authCallProvider.authenticatedMethod())
            try await processCurrentUserProfileResponse(profileResponse, userId: userData.id)
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
        try await createOrUpdateUserProfile(with: profile)
    }

    func deleteCurrentUserProfile(profileId: String) async throws {
        try await userProfileDatabase.delete(profileId: profileId)
    }

    func resetNotificationBadgeCount() async throws {
        guard let profile else { throw InternalError.incorrectState }
        try await userProfileDatabase.resetNotificationBadgeCount(on: profile.id)
    }

    // MARK: Other users APIs

    public func getProfile(profileId: String) -> AnyPublisher<Profile?, Error> {
        publicProfileDatabase.profilePublisher(profileId: profileId)
            .map { [unowned self] in
                guard let storableProfile = $0 else { return nil }
                return Profile(storableProfile: storableProfile, postFeedsStore: postFeedsStore)
            }
            .eraseToAnyPublisher()
    }

    public func fetchProfile(profileId: String) async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let profileResponse = try await remoteClient.userService.getPublicProfile(
                profileId: profileId,
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            try await publicProfileDatabase.upsert(profile: StorableProfile(from: profileResponse.profile))
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
        return (CurrentUserProfile(storableProfile: storableProfile, postFeedsStore: postFeedsStore), pictureData)
    }

    private func processCurrentUserProfileResponse(_ response: Com_Octopuscommunity_GetPrivateProfileResponse,
                                                   userId: String) async throws {
        if !(try await migrateUserToFrictionlessUserIfNeeded(response: response, userId: userId)) {
            guard response.hasProfile,
                  let profile = StorableCurrentUserProfile(from: response.profile, userId: userId) else {
                throw InternalError.objectMalformed
            }
            try await userProfileDatabase.upsert(profile: profile)
        }
    }

    private func migrateUserToFrictionlessUserIfNeeded(
        response: Com_Octopuscommunity_GetPrivateProfileResponse,
        userId: String) async throws -> Bool {
            guard response.hasProfile else {
                throw InternalError.objectMalformed
            }
            // profile need migration only if hasConfirmedNickname is null
            guard !response.profile.hasHasConfirmedNickname_p else {
                return false
            }
            if #available(iOS 14, *) { Logger.profile.debug("Migrating user to a frictionless one.") }
            // if nickname is not present, ask the backend to create one.
            let profile: UpdateProfileData
            if response.profile.nickname.nilIfEmpty != nil {
                // This is the case of a fully created profile but comming from a non-frictionless env
                profile = .init(
                    hasSeenOnboarding: .updated(true),
                    hasAcceptedCgu: .updated(true),
                    hasConfirmedNickname: .updated(true),
                    hasConfirmedBio: .updated(true),
                    hasConfirmedPicture: .updated(true)
                )
            } else {
                // This is the case where the user was logged in before migration but has never passed the profile
                // creation step.
                profile = .init(
                    hasSeenOnboarding: .updated(false),
                    hasAcceptedCgu: .updated(false),
                    hasConfirmedNickname: .updated(false),
                    hasConfirmedBio: .updated(false),
                    hasConfirmedPicture: .updated(false),
                    optFindAvailableNickname: true
                )
            }
            let response = try await remoteClient.userService.updateProfile(
                userId: userId,
                profile: profile,
                authenticationMethod: try authCallProvider.authenticatedMethod())
            switch response.result {
            case let .success(content):
                if let profile = StorableCurrentUserProfile(from: content.profile, userId: userId) {
                    try await userProfileDatabase.upsert(profile: profile)
                } else {
                    throw UpdateProfile.Error.serverCall(.other(nil))
                }

            case let .fail(failure):
                throw UpdateProfile.Error.validation(.init(from: failure))
            case .none:
                throw UpdateProfile.Error.serverCall(.other(nil))
            }
            return true
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
            var pictureUpdate: EditableProfile.FieldUpdate<(imgData: Data, isCompressed: Bool)?> = .notUpdated
            if case let .updated(imageData) = profile.picture, let imageData {
                let (resizedImgData, isCompressed) = ImageResizer.resizeIfNeeded(imageData: imageData)
                resizedPicture = resizedImgData
                pictureUpdate = .updated((imgData: resizedImgData, isCompressed: isCompressed))
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
                    optFindAvailableNickname: findAvailableNickname
                ),
                authenticationMethod: try authCallProvider.authenticatedMethod())
            switch response.result {
            case let .success(content):
                if let profile = StorableCurrentUserProfile(from: content.profile, userId: userData.id) {
                    try await userProfileDatabase.upsert(profile: profile)
                    _onCurrentUserProfileUpdated.send()
                    return (profile, resizedPicture)
                } else {
                    throw UpdateProfile.Error.serverCall(.other(nil))
                }

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
    async throws(UpdateProfile.Error) -> (StorableCurrentUserProfile, Data?)? {
        guard !profile.isGuest else { throw .serverCall(.other(InternalError.incorrectState)) }

        var hasUpdate = false
        let nickname: EditableProfile.FieldUpdate<String>
        let hasConfirmedNickname: EditableProfile.FieldUpdate<Bool>
        let findAvailableNickname: Bool
        // update the field if is appManaged or if the user has not yet confirmed it
        if (appManagedFields.contains(.nickname) || !profile.hasConfirmedNickname),
           let clientNickname = clientUser.profile.nickname?.nilIfEmpty,
           // check with the original nickname first because the nickname can vary from the one requested
           (profile.originalNickname ?? profile.nickname) != clientNickname {
            if #available(iOS 14, *) { Logger.profile.trace("Nickname changed (old: \(profile.nickname), new: \(clientNickname))") }
            nickname = .updated(clientNickname)
            hasConfirmedNickname = appManagedFields.contains(.nickname) ? .updated(true) : .notUpdated
            findAvailableNickname = !appManagedFields.contains(.nickname)
            hasUpdate = true
        } else {
            nickname = .notUpdated
            hasConfirmedNickname = .notUpdated
            findAvailableNickname = false
        }

        let bio: EditableProfile.FieldUpdate<String?>
        let hasConfirmedBio: EditableProfile.FieldUpdate<Bool>
        if (appManagedFields.contains(.bio) || !profile.hasConfirmedBio),
            profile.bio != clientUser.profile.bio {
            if #available(iOS 14, *) { Logger.profile.trace("Bio changed (old: \(profile.bio ?? "nil"), new: \(clientUser.profile.bio ?? "nil"))") }
            bio = .updated(clientUser.profile.bio)
            hasConfirmedBio = appManagedFields.contains(.bio) ? .updated(true) : .notUpdated
            hasUpdate = true
        } else {
            bio = .notUpdated
            hasConfirmedBio = .notUpdated
        }

        let picture: EditableProfile.FieldUpdate<Data?>
        let hasConfirmedPicture: EditableProfile.FieldUpdate<Bool>
        if (appManagedFields.contains(.picture) || !profile.hasConfirmedPicture),
            latestClientUserPicture != clientUser.profile.picture {
            if #available(iOS 14, *) { Logger.profile.trace("Picture changed") }
            picture = .updated(clientUser.profile.picture)
            hasConfirmedPicture = appManagedFields.contains(.picture) ? .updated(true) : .notUpdated
            hasUpdate = true
        } else {
            picture = .notUpdated
            hasConfirmedPicture = .notUpdated
        }

        guard hasUpdate else { return nil }
        let previousClientUserPicture = latestClientUserPicture
        do {
            latestClientUserPicture = clientUser.profile.picture
            return try await internalUpdateUserProfile(
                with: EditableProfile(
                    nickname: nickname,
                    bio: bio,
                    picture: picture,
                    hasConfirmedNickname: hasConfirmedNickname,
                    hasConfirmedBio: hasConfirmedBio,
                    hasConfirmedPicture: hasConfirmedPicture
                ),
                findAvailableNickname: findAvailableNickname)
        } catch {
            // rollback client picture hash
            latestClientUserPicture = previousClientUserPicture
            if #available(iOS 14, *) { Logger.profile.debug("Error syncing profile: \(error)") }
            return nil
        }
    }
}
