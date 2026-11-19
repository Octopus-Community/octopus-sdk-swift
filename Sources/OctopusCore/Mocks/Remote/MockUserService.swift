//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels

class MockUserService: UserService {
    /// Fifo of the responses to `getPublicProfile`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getPublicProfileResponses = [Result<Com_Octopuscommunity_GetPublicProfileResponse, RemoteClientError>]()
    /// Fifo of the responses to `getPublicProfile(clientUserId:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getPublicProfileByClientUserIdResponses =
        [Result<Com_Octopuscommunity_GetPublicProfileResponse, RemoteClientError>]()
    /// Fifo of the responses to `getProfile`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getPrivateProfileResponses = [Com_Octopuscommunity_GetPrivateProfileResponse]()
    /// Fifo of the responses to `updateProfile`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var updateProfileResponses = [Result<Com_Octopuscommunity_UpdateProfileResponse, RemoteClientError>]()
    /// Fifo of the responses to `reportUser`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var reportUserResponses = [Com_Octopuscommunity_ReportUserResponse]()
    /// Fifo of the responses to `blockUser`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var blockUserResponses = [Com_Octopuscommunity_BlockUserResponse]()
    /// Fifo of the responses to `getJwtFromClientToken`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getJwtFromClientTokenResponses = [Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse]()
    /// Fifo of the responses to `getGuestJwt`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getGuestJwtResponses = [Com_Octopuscommunity_GetGuestJwtResponse]()
    /// Fifo of the responses to `canAccessCommunity`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var canAccessCommunityResponses =
        [Result<Com_Octopuscommunity_CanAccessCommunityResponse, RemoteClientError>]()
    /// Fifo of the responses to `bypassABTesting`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var bypassABTestingResponses = [Com_Octopuscommunity_ByPassAbTestingResponse]()
    /// Fifo of the responses to `enteringOctopus`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var enteringOctopusResponses = [Com_Octopuscommunity_EnteringOctopusResponse]()
    /// Fifo of the responses to `followTopic`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var followTopicResponses = [Com_Octopuscommunity_FollowUnfollowTopicResponse]()
    /// Fifo of the responses to `unfollowTopic`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var unfollowTopicResponses = [Com_Octopuscommunity_FollowUnfollowTopicResponse]()
    /// Fifo of the responses to `syncFollowTopics`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var syncFollowTopicsResponses = [Com_Octopuscommunity_SyncFollowTopicsResponse]()

    /// Number of times syncFollowTopics has been called. Useful to assert no-network-call behavior.
    private(set) var syncFollowTopicsCallCount = 0
    private(set) var getGuestJwtCallCount = 0
    /// Number of times a client token has been exchanged for a JWT.
    private(set) var getJwtCallCount = 0
    /// For each call to `getJwt`, whether it was sent with the token of the current session.
    private(set) var getJwtAuthenticatedFlags = [Bool]()
    /// Thrown by `getJwt` and `getGuestJwt` instead of their next response, when set.
    var getJwtError: RemoteClientError?
    var getGuestJwtError: RemoteClientError?
    /// Number of times the server has been told the Octopus UI is displayed.
    private(set) var enteringOctopusCallCount = 0
    /// Run before `canAccessCommunity` answers, to change the state while the call is in flight.
    var canAccessCommunityHook: (@Sendable () async -> Void)?
    /// Run when `getJwt` is called, before it answers.
    var getJwtHook: (@Sendable () -> Void)?

    /// The last actions passed to syncFollowTopics. Useful to assert correct proto mapping.
    private(set) var lastSyncFollowTopicsActions: [Com_Octopuscommunity_SyncFollowTopicAction] = []

    private(set) var errorMessage: String?

    /// The profile update `updateProfile` received last. Useful to assert what the repository sends.
    var lastUpdateProfileData: UpdateProfileData? {
        updateProfileLock.lock()
        defer { updateProfileLock.unlock() }
        return _lastUpdateProfileData
    }
    private var _lastUpdateProfileData: UpdateProfileData?
    /// Number of times a profile update has been sent.
    var updateProfileCallCount: Int {
        updateProfileLock.lock()
        defer { updateProfileLock.unlock() }
        return _updateProfileCallCount
    }
    private var _updateProfileCallCount = 0
    /// Whether `updateProfile` calls wait for `releaseUpdateProfile()` before answering.
    private var updateProfileIsHeld = false
    /// The `updateProfile` calls waiting for `releaseUpdateProfile()`.
    private var heldUpdateProfiles = [CheckedContinuation<Void, Never>]()
    /// Guards the state of `updateProfile`, which two overlapping updates change at the same time.
    private let updateProfileLock = NSLock()
    /// How long `getPrivateProfile` takes to answer once it has taken its response, in nanoseconds. Lets the session
    /// change while a fetch is in flight.
    var getPrivateProfileLatency: UInt64 = 0
    /// Awaited by both `getPublicProfile` before they answer: lets a test hold that answer while other calls go through.
    var getPublicProfileHold: (@Sendable () async -> Void)?
    /// Awaited by `getPrivateProfile` before it answers: lets a test act while the request is sent and not answered.
    var getPrivateProfileHold: (@Sendable () async -> Void)?
    /// Guards the responses of `getPrivateProfile`, which two overlapping fetches take at the same time.
    private let getPrivateProfileLock = NSLock()

    /// Number of times the community access has been asked, read from the test while the monitor's task calls.
    var canAccessCommunityCallCount: Int {
        canAccessCommunityLock.lock()
        defer { canAccessCommunityLock.unlock() }
        return _canAccessCommunityCallCount
    }
    private var _canAccessCommunityCallCount = 0
    /// Guards the state of `canAccessCommunity`, called from a task while the test injects and reads.
    private let canAccessCommunityLock = NSLock()

    func getPublicProfile(profileId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetPublicProfileResponse {
        guard let response = getPublicProfileResponses.popLast() else {
            let message = "Dev error, injectNextGetPublicProfileResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        if let getPublicProfileHold { await getPublicProfileHold() }
        return try response.get()
    }

    func getPublicProfile(clientUserId: String, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_GetPublicProfileResponse {
        guard let response = getPublicProfileByClientUserIdResponses.popLast() else {
            let message = "Dev error, injectNextGetPublicProfileByClientUserIdResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        if let getPublicProfileHold { await getPublicProfileHold() }
        return try response.get()
    }

    func getPrivateProfile(userId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetPrivateProfileResponse {
        guard let response = popGetPrivateProfileResponse() else {
            let message = "Dev error, injectNextGetPrivateProfileResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        if getPrivateProfileLatency > 0 { try? await Task.sleep(nanoseconds: getPrivateProfileLatency) }
        if let getPrivateProfileHold { await getPrivateProfileHold() }
        return response
    }

    private func popGetPrivateProfileResponse() -> Com_Octopuscommunity_GetPrivateProfileResponse? {
        getPrivateProfileLock.lock()
        defer { getPrivateProfileLock.unlock() }
        return getPrivateProfileResponses.popLast()
    }

    func updateProfile(userId: String,
                       profile: UpdateProfileData,
                       authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_UpdateProfileResponse {
        let response = recordUpdateProfile(profile)
        await withCheckedContinuation { waitForUpdateProfileRelease($0) }
        guard let response else {
            let message = "Dev error, injectNextUpdateProfileResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return try response.get()
    }

    /// Counts the call and pops its response before it is held: overlapping updates get the responses in the order
    /// they were sent, not in the order they are released.
    private func recordUpdateProfile(_ profile: UpdateProfileData)
    -> Result<Com_Octopuscommunity_UpdateProfileResponse, RemoteClientError>? {
        updateProfileLock.lock()
        defer { updateProfileLock.unlock() }
        _lastUpdateProfileData = profile
        _updateProfileCallCount += 1
        return updateProfileResponses.popLast()
    }

    /// Resumes `continuation` now, or once `releaseUpdateProfile()` is called while the calls are held.
    private func waitForUpdateProfileRelease(_ continuation: CheckedContinuation<Void, Never>) {
        updateProfileLock.lock()
        guard updateProfileIsHeld else {
            updateProfileLock.unlock()
            continuation.resume()
            return
        }
        heldUpdateProfiles.append(continuation)
        updateProfileLock.unlock()
    }

    func deleteUser(userId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteUserResponse {
        fatalError("Not implemented")
    }

    func reportUser(profileId: String, reasons: [Com_Octopuscommunity_ReportReasonCode],
                    authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_ReportUserResponse {
        guard let response = reportUserResponses.popLast() else {
            let message = "Dev error, injectNextDeleteProfileResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func blockUser(profileId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_BlockUserResponse {
        guard let response = blockUserResponses.popLast() else {
            let message = "Dev error, injectNextBlockUserResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func getJwt(clientToken: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse {
        getJwtCallCount += 1
        getJwtHook?()
        if case .authenticated = authenticationMethod {
            getJwtAuthenticatedFlags.append(true)
        } else {
            getJwtAuthenticatedFlags.append(false)
        }
        try? await Task.sleep(nanoseconds: UInt64.random(in: 0..<10) * 1_000_000)
        if let getJwtError { throw getJwtError }
        guard let response = getJwtFromClientTokenResponses.popLast() else {
            let message = "Dev error, injectNextGetJwtFromClientResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func getGuestJwt() async throws(RemoteClientError) -> Com_Octopuscommunity_GetGuestJwtResponse {
        getGuestJwtCallCount += 1
        do {
            try await Task.sleep(nanoseconds: UInt64.random(in: 0..<10) * 1_000_000)
        } catch { throw .unknown(MockError("Unknown error")) }
        if let getGuestJwtError { throw getGuestJwtError }
        guard let response = getGuestJwtResponses.popLast() else {
            let message = "Dev error, injectNextGetGuestJwt must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func canAccessCommunity(authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_CanAccessCommunityResponse {
        await canAccessCommunityHook?()
        guard let response = popCanAccessCommunityResponse() else {
            let message = "Dev error, injectNextCanAccessCommunityResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return try response.get()
    }

    /// Counts the call and pops its response, under the lock: an `async` function cannot hold an `NSLock`.
    private func popCanAccessCommunityResponse()
    -> Result<Com_Octopuscommunity_CanAccessCommunityResponse, RemoteClientError>? {
        canAccessCommunityLock.lock()
        defer { canAccessCommunityLock.unlock() }
        _canAccessCommunityCallCount += 1
        return canAccessCommunityResponses.popLast()
    }

    func bypassABTestingAccess(userId: String, canAccessCommunity: Bool, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_ByPassAbTestingResponse {
        guard let response = bypassABTestingResponses.popLast() else {
            let message = "Dev error, injectNextBlockUserResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func enteringOctopus(authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_EnteringOctopusResponse {
        enteringOctopusCallCount += 1
        guard let response = enteringOctopusResponses.popLast() else {
            let message = "Dev error, injectNextEnteringOctopusResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func followTopic(topicId: String, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_FollowUnfollowTopicResponse {
        guard let response = followTopicResponses.popLast() else {
            let message = "Dev error, injectNextFollowTopicResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func unfollowTopic(topicId: String, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_FollowUnfollowTopicResponse {
        guard let response = unfollowTopicResponses.popLast() else {
            let message = "Dev error, injectNextUnfollowTopicResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func syncFollowTopics(
        actions: [Com_Octopuscommunity_SyncFollowTopicAction],
        authenticationMethod: AuthenticationMethod
    ) async throws(RemoteClientError) -> Com_Octopuscommunity_SyncFollowTopicsResponse {
        syncFollowTopicsCallCount += 1
        lastSyncFollowTopicsActions = actions
        guard let response = syncFollowTopicsResponses.popLast() else {
            let message = "Dev error, injectNextSyncFollowTopicsResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }
}

extension MockUserService {
    func injectNextGetPublicProfileResponse(_ response: Com_Octopuscommunity_GetPublicProfileResponse) {
        getPublicProfileResponses.insert(.success(response), at: 0)
    }

    func injectNextGetPublicProfileError(_ error: RemoteClientError) {
        getPublicProfileResponses.insert(.failure(error), at: 0)
    }

    func injectNextGetPublicProfileByClientUserIdError(_ error: RemoteClientError) {
        getPublicProfileByClientUserIdResponses.insert(.failure(error), at: 0)
    }

    func injectNextGetPublicProfileByClientUserIdResponse(_ response: Com_Octopuscommunity_GetPublicProfileResponse) {
        getPublicProfileByClientUserIdResponses.insert(.success(response), at: 0)
    }

    func injectNextGetPrivateProfileResponse(_ response: Com_Octopuscommunity_GetPrivateProfileResponse) {
        getPrivateProfileLock.lock()
        defer { getPrivateProfileLock.unlock() }
        getPrivateProfileResponses.insert(response, at: 0)
    }

    func injectNextUpdateProfileResponse(_ response: Com_Octopuscommunity_UpdateProfileResponse) {
        updateProfileLock.lock()
        defer { updateProfileLock.unlock() }
        updateProfileResponses.insert(.success(response), at: 0)
    }

    func injectNextUpdateProfileError(_ error: RemoteClientError) {
        updateProfileLock.lock()
        defer { updateProfileLock.unlock() }
        updateProfileResponses.insert(.failure(error), at: 0)
    }

    /// Holds the next `updateProfile` calls until `releaseUpdateProfile()`: a test keeps an update in flight while
    /// another caller starts, rather than giving the update a latency and hoping the caller starts within it.
    /// The calls are still counted, and take their response, when they arrive.
    /// Follow it with `defer { releaseUpdateProfile() }`: a held call ignores cancellation, so a test that fails
    /// before releasing would otherwise leave its tasks waiting forever.
    func holdUpdateProfile() {
        updateProfileLock.lock()
        defer { updateProfileLock.unlock() }
        updateProfileIsHeld = true
    }

    /// Answers the `updateProfile` calls held since `holdUpdateProfile()`, and lets the next ones answer at once.
    func releaseUpdateProfile() {
        updateProfileLock.lock()
        updateProfileIsHeld = false
        let heldCalls = heldUpdateProfiles
        heldUpdateProfiles = []
        updateProfileLock.unlock()
        heldCalls.forEach { $0.resume() }
    }

    func injectNextCanAccessCommunityResponse(_ response: Com_Octopuscommunity_CanAccessCommunityResponse) {
        canAccessCommunityLock.lock()
        defer { canAccessCommunityLock.unlock() }
        canAccessCommunityResponses.insert(.success(response), at: 0)
    }

    func injectNextCanAccessCommunityError(_ error: RemoteClientError) {
        canAccessCommunityLock.lock()
        defer { canAccessCommunityLock.unlock() }
        canAccessCommunityResponses.insert(.failure(error), at: 0)
    }

    func injectNextReportUserResponse(_ response: Com_Octopuscommunity_ReportUserResponse) {
        reportUserResponses.insert(response, at: 0)
    }

    func injectNextBlockUserResponse(_ response: Com_Octopuscommunity_BlockUserResponse) {
        blockUserResponses.insert(response, at: 0)
    }

    func injectNextGetJwtFromClientResponse(_ response: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse) {
        getJwtFromClientTokenResponses.insert(response, at: 0)
    }

    func injectNextGetGuestJwtResponse(_ response: Com_Octopuscommunity_GetGuestJwtResponse) {
        getGuestJwtResponses.insert(response, at: 0)
    }

    func injectNextEnteringOctopusResponse(_ response: Com_Octopuscommunity_EnteringOctopusResponse) {
        enteringOctopusResponses.insert(response, at: 0)
    }

    func injectNextFollowTopicResponse(_ response: Com_Octopuscommunity_FollowUnfollowTopicResponse) {
        followTopicResponses.insert(response, at: 0)
    }

    func injectNextunfollowTopicResponse(_ response: Com_Octopuscommunity_FollowUnfollowTopicResponse) {
        unfollowTopicResponses.insert(response, at: 0)
    }

    func injectNextSyncFollowTopicsResponse(_ response: Com_Octopuscommunity_SyncFollowTopicsResponse) {
        syncFollowTopicsResponses.insert(response, at: 0)
    }
}
