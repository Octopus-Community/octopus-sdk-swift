//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import UIKit
import OctopusGrpcModels
import OctopusRemoteClient
import OctopusDependencyInjection
@testable import OctopusCore

/// Posts and bridge posts reference their photos by upload id instead of carrying their bytes.
struct PostUploadsTests {

    // MARK: - Sending a post

    @Test func sendingAPostUploadsItsPhotosThenReferencesThem() async throws {
        let sut = Sut()
        let images = [Data([1]), Data([2, 2]), Data([3, 3, 3])]
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 3))
        sut.injectPutPostSuccess()

        _ = try await sut.repository.send(
            WritablePost(topicId: "topicId", text: "A post with three photos", images: images))

        #expect(sut.octoService.createImageUploadsSizes == [[1, 2, 3]])
        let puts = await sut.httpClient.puts
        #expect(Set(puts.map(\.body)) == Set(images))
        let sent = try #require(sut.octoService.lastPutPostRwOctoObject).content.post.media.images
        #expect(sent.map(\.uploadID) == ["id0", "id1", "id2"])
        // The bytes are not a decodable image: the resizer leaves them as they are and does not call them optimized.
        #expect(sent.map(\.isOptimized) == [false, false, false])
        #expect(sent.allSatisfy { $0.bytes.isEmpty && $0.url.isEmpty })
    }

    @Test func aSinglePhotoAlsoGoesThroughUploads() async throws {
        let sut = Sut()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectPutPostSuccess()

        _ = try await sut.repository.send(
            WritablePost(topicId: "topicId", text: "A post with one photo", images: [Data([1, 2])]))

        #expect(sut.octoService.createImageUploadsSizes == [[2]])
        let sent = try #require(sut.octoService.lastPutPostRwOctoObject).content.post.media.images
        #expect(sent.map(\.file) == [.uploadID("id0")])
        #expect(sent.first?.isOptimized == false)
    }

    @Test func aPostIsPutWithAnAuthenticatedMethodLikeItsUploads() async throws {
        let sut = Sut()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectPutPostSuccess()

        _ = try await sut.repository.send(
            WritablePost(topicId: "topicId", text: "A post with one photo", images: [Data([1, 2])]))

        let uploadMethod = try #require(sut.octoService.createImageUploadsAuthenticationMethods.first)
        let putMethod = try #require(sut.octoService.lastPutPostAuthenticationMethod)
        guard case .authenticated = uploadMethod, case .authenticated = putMethod else {
            Issue.record("Unexpected methods \(uploadMethod) and \(putMethod)")
            return
        }
    }

    @Test func aPostIsPutWithTheTokenReadAfterItsUploads() async throws {
        let sut = Sut()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))
        sut.injectPutPostSuccess()
        // The token rotates while the photos are on their way to the storage.
        sut.octoService.onCreateImageUploads = { [authProvider = sut.authProvider] in authProvider.token = "rotated" }

        _ = try await sut.repository.send(
            WritablePost(topicId: "topicId", text: "A post with photos", images: [Data([1]), Data([2])]))

        let uploadMethod = try #require(sut.octoService.createImageUploadsAuthenticationMethods.first)
        let putMethod = try #require(sut.octoService.lastPutPostAuthenticationMethod)
        guard case let .authenticated(uploadToken, _) = uploadMethod,
              case let .authenticated(putToken, _) = putMethod else {
            Issue.record("Unexpected methods \(uploadMethod) and \(putMethod)")
            return
        }
        #expect(uploadToken == "fake_token")
        #expect(putToken == "rotated")
    }

    @Test func eachPhotoKeepsTheOptimizedFlagTheResizerGaveIt() async throws {
        let sut = Sut()
        // A PNG with alpha is not recompressed by the resizer (it stays a PNG), a JPEG is.
        let imagesAndFlags: [(Data, Bool)] = [(try Self.transparentPng(), false), (try Self.largeJpeg(), true),
                                              (try Self.transparentPng(), false)]
        for (data, expected) in imagesAndFlags {
            #expect(ImageResizer.resizeIfNeeded(imageData: data).isCompressed == expected)
        }
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 3))
        sut.injectPutPostSuccess()

        _ = try await sut.repository.send(
            WritablePost(topicId: "topicId", text: "A post with mixed photos", images: imagesAndFlags.map(\.0)))

        let sent = try #require(sut.octoService.lastPutPostRwOctoObject).content.post.media.images
        #expect(sent.map(\.uploadID) == ["id0", "id1", "id2"])
        #expect(sent.map(\.isOptimized) == [false, true, false])
    }

    @Test(arguments: [URLError.Code.networkConnectionLost, .dataNotAllowed, .cannotFindHost])
    func aPostPhotoUploadLostToTheNetworkFailsTheSendWithNoNetwork(code: URLError.Code) async throws {
        let sut = Sut(urlErrorCodes: [FakeImageUploadHTTPClient.url(1): code])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))

        do {
            _ = try await sut.repository.send(
                WritablePost(topicId: "topicId", text: "A post with photos", images: [Data([1]), Data([2])]))
            Issue.record("The send should have failed")
        } catch {
            guard case .serverCall(.noNetwork) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
        #expect(sut.octoService.lastPutPostRwOctoObject == nil)
    }

    @Test func aPostPhotoUploadFailingOtherwiseStaysAGenericError() async throws {
        let sut = Sut(urlErrorCodes: [FakeImageUploadHTTPClient.url(0): .badServerResponse])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))

        do {
            _ = try await sut.repository.send(
                WritablePost(topicId: "topicId", text: "A post with a photo", images: [Data([1])]))
            Issue.record("The send should have failed")
        } catch {
            guard case .serverCall(.other) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
    }

    @Test func aPostWithoutPhotoMakesNoUploadCall() async throws {
        let sut = Sut()
        sut.injectPutPostSuccess()

        _ = try await sut.repository.send(WritablePost(topicId: "topicId", text: "A post with only text"))

        #expect(sut.octoService.createImageUploadsSizes.isEmpty)
        #expect(await sut.httpClient.puts.isEmpty)
        let sent = try #require(sut.octoService.lastPutPostRwOctoObject).content.post
        #expect(!sent.hasMedia)
    }

    @Test func refusedUploadBecomesAPictureValidationErrorWithItsIndex() async throws {
        let sut = Sut()
        sut.octoService.injectNextCreateImageUploadsResponse(.with {
            $0.fail = .with {
                $0.errors = [.with {
                    $0.message = "This photo is too big"
                    $0.fileIndex = 1
                    $0.details = .fileSizeTooBig(.init())
                }]
            }
        })

        do {
            _ = try await sut.repository.send(
                WritablePost(topicId: "topicId", text: "A post with photos", images: [Data([1]), Data([2])]))
            Issue.record("The send should have been refused")
        } catch {
            guard case let .validation(validation) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            let pictureErrors = try #require(validation.errors[.linkedToField(.picture)])
            #expect(pictureErrors.count == 1)
            #expect(pictureErrors.first?.imageIndex == 1)
            #expect(pictureErrors.first?.localizedMessage == "This photo is too big")
            guard case .fileSizeTooBig? = pictureErrors.first?.detail else {
                Issue.record("Unexpected detail \(String(describing: pictureErrors.first?.detail))")
                return
            }
        }
        #expect(sut.octoService.lastPutPostRwOctoObject == nil)
        #expect(await sut.httpClient.puts.isEmpty)
    }

    @Test func putPostErrorCarriesItsImageIndex() async throws {
        let sut = Sut()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))
        sut.octoService.injectNextPutPostResponse(.with {
            $0.result = .fail(.with {
                $0.errors = [
                    .with {
                        $0.message = "Bad format"
                        $0.field = .contentFile
                        $0.fileIndex = 0
                        $0.details = .badFileFormat(.init())
                    },
                    .with {
                        $0.message = "Too long"
                        $0.field = .contentText
                        $0.details = .maxCharLimitReached(.init())
                    }
                ]
            })
        })

        do {
            _ = try await sut.repository.send(
                WritablePost(topicId: "topicId", text: "A post with photos", images: [Data([1]), Data([2])]))
            Issue.record("The send should have been refused")
        } catch {
            guard case let .validation(validation) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(validation.errors[.linkedToField(.picture)]?.first?.imageIndex == 0)
            #expect(validation.errors[.linkedToField(.text)]?.first?.imageIndex == nil)
        }
    }

    @Test func aFailedUploadFailsTheSendWithoutPutPost() async throws {
        let sut = Sut(statuses: [FakeImageUploadHTTPClient.url(1): 403])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))

        do {
            _ = try await sut.repository.send(
                WritablePost(topicId: "topicId", text: "A post with photos", images: [Data([1]), Data([2])]))
            Issue.record("The send should have failed")
        } catch {
            guard case .serverCall(.other) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
        #expect(sut.octoService.lastPutPostRwOctoObject == nil)
    }

    @Test func aFailedUploadCallFailsTheSendWithoutPutPost() async throws {
        let sut = Sut()
        // No upload response injected: the mocked call throws.

        do {
            _ = try await sut.repository.send(
                WritablePost(topicId: "topicId", text: "A post with photos", images: [Data([1])]))
            Issue.record("The send should have failed")
        } catch {
            guard case .serverCall(.serverError) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
        #expect(sut.octoService.lastPutPostRwOctoObject == nil)
    }

    @Test func shareFingerprintStillCoversTheResizedBytes() async throws {
        let sut = Sut()
        let original = try Self.largeJpeg()
        let resized = ImageResizer.resizeIfNeeded(imageData: original).imgData
        #expect(resized != original)
        let fingerprints = FingerprintRecorder()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectPutPostSuccess()

        let (_, sentImages) = try await sut.repository.send(
            WritablePost(topicId: "topicId", text: "Shared text", images: [original]),
            creationSource: .prefilledFromClient,
            bridgeShareSignature: { fingerprint in
                await fingerprints.record(fingerprint)
                return "client-token"
            })

        #expect(await fingerprints.values == [BridgeShareFingerprint.compute(
            text: "Shared text", ctaText: nil, ctaTargetLink: nil, images: [.bytes(resized)])])
        #expect(sut.octoService.createImageUploadsSizes == [[UInt64(resized.count)]])
        #expect(await sut.httpClient.puts.map(\.body) == [resized])
        #expect(sentImages == [resized])
        #expect(sut.octoService.lastPutPostClientToken == "client-token")
    }

    @Test func sendingAPostSendsNoBridgeBlock() async throws {
        let sut = Sut()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectPutPostSuccess()

        _ = try await sut.repository.send(
            WritablePost(topicId: "topicId", text: "A post with one photo", images: [Data([1, 2])]))

        #expect(sut.octoService.createImageUploadsBridges == [nil])
    }

    @Test func sharingAPrefilledPostSendsNoBridgeBlock() async throws {
        let sut = Sut()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectPutPostSuccess()

        _ = try await sut.repository.send(
            WritablePost(topicId: "topicId", text: "Shared text", images: [Data([1, 2])]),
            creationSource: .prefilledFromClient,
            bridgeShareSignature: { _ in "client-token" })

        // The share is signed, but it is the member's own upload: the token goes to the post, not to the upload.
        #expect(sut.octoService.createImageUploadsBridges == [nil])
        #expect(sut.octoService.lastPutPostClientToken == "client-token")
    }

    // MARK: - Bridge post creation

    @Test func bridgeCreationUploadsLocalImagesAndKeepsDistantURLs() async throws {
        let sut = Sut()
        let distant = URL(string: "https://a.example/2.jpg")!
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))
        sut.injectBridgePostSuccess()

        _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
            content: Self.clientPost(medias: [.localImage(Data([1])), .distantImage(distant),
                                              .localImage(Data([2, 2]))]),
            tokenProvider: { _ in "token" })

        #expect(sut.octoService.createImageUploadsSizes == [[1, 2]])
        let puts = await sut.httpClient.puts
        #expect(puts.first { $0.url == FakeImageUploadHTTPClient.url(0) }?.body == Data([1]))
        #expect(puts.first { $0.url == FakeImageUploadHTTPClient.url(1) }?.body == Data([2, 2]))
        let sent = try #require(sut.octoService.lastCreateBridgePost).media.images
        #expect(sent.map(\.file) == [.uploadID("id0"), .url(distant.absoluteString), .uploadID("id1")])
        #expect(sent[0].isOptimized)
        #expect(sent[2].isOptimized)
    }

    @Test func bridgeUploadNamesTheClientObjectAndCarriesTheTokenOfTheCreation() async throws {
        let sut = Sut()
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectBridgePostSuccess()

        _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
            content: Self.clientPost(medias: [.localImage(Data([1]))]), tokenProvider: { _ in "token" })

        let firstCall = try #require(sut.octoService.createImageUploadsBridges.first)
        let bridge = try #require(firstCall)
        #expect(sut.octoService.createImageUploadsBridges.count == 1)
        #expect(bridge.clientObjectID == "clientObjectId")
        #expect(bridge.hasClientToken)
        #expect(bridge.clientToken == "token")
        #expect(sut.octoService.lastCreateBridgePostClientToken == bridge.clientToken)
    }

    @Test(arguments: [nil, ""] as [String?])
    func bridgeUploadOfAnUnsignedPostNamesTheClientObjectWithoutToken(token: String?) async throws {
        let sut = Sut()
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectBridgePostSuccess()

        _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
            content: Self.clientPost(medias: [.localImage(Data([1]))]), tokenProvider: { _ in token })

        let firstCall = try #require(sut.octoService.createImageUploadsBridges.first)
        let bridge = try #require(firstCall)
        #expect(bridge.clientObjectID == "clientObjectId")
        #expect(!bridge.hasClientToken)
    }

    @Test func bridgeCreationUploadsTheClientBytesUnchanged() async throws {
        let sut = Sut()
        let original = try Self.largeJpeg()
        #expect(ImageResizer.resizeIfNeeded(imageData: original).imgData != original)
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectBridgePostSuccess()

        _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
            content: Self.clientPost(medias: [.localImage(original)]), tokenProvider: { _ in nil })

        #expect(sut.octoService.createImageUploadsSizes == [[UInt64(original.count)]])
        #expect(await sut.httpClient.puts.map(\.body) == [original])
        let sent = try #require(sut.octoService.lastCreateBridgePost).media.images
        #expect(sent.map(\.file) == [.uploadID("id0")])
        #expect(sent.first?.isOptimized == true)
    }

    @Test func bridgeCreationAsAnUnconnectedVisitorUploadsAndCreatesNotAuthenticated() async throws {
        let sut = Sut()
        sut.authProvider.isConnected = false
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectBridgePostSuccess()

        let post = try await sut.repository.getOrCreateClientObjectRelatedPost(
            content: Self.clientPost(medias: [.localImage(Data([1]))]), tokenProvider: { _ in "token" })

        #expect(post.id == "bridgeId")
        let uploadMethod = try #require(sut.octoService.createImageUploadsAuthenticationMethods.first)
        let createMethod = try #require(sut.octoService.lastCreateBridgePostAuthenticationMethod)
        #expect(sut.octoService.createImageUploadsAuthenticationMethods.count == 1)
        guard case .notAuthenticated = uploadMethod, case .notAuthenticated = createMethod else {
            Issue.record("Unexpected methods \(uploadMethod) and \(createMethod)")
            return
        }
        #expect(sut.octoService.lastCreateBridgePost?.media.images.map(\.uploadID) == ["id0"])
    }

    @Test func bridgeCreationAsAConnectedUserUploadsAndCreatesAuthenticated() async throws {
        let sut = Sut()
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectBridgePostSuccess()

        _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
            content: Self.clientPost(medias: [.localImage(Data([1]))]), tokenProvider: { _ in "token" })

        let uploadMethod = try #require(sut.octoService.createImageUploadsAuthenticationMethods.first)
        let createMethod = try #require(sut.octoService.lastCreateBridgePostAuthenticationMethod)
        guard case .authenticated = uploadMethod, case .authenticated = createMethod else {
            Issue.record("Unexpected methods \(uploadMethod) and \(createMethod)")
            return
        }
    }

    @Test func bridgeCreationReadsTheTokenAgainAfterTheUploads() async throws {
        let sut = Sut()
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectBridgePostSuccess()
        // The token rotates while the photos are on their way to the storage.
        sut.octoService.onCreateImageUploads = { [authProvider = sut.authProvider] in authProvider.token = "rotated" }

        _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
            content: Self.clientPost(medias: [.localImage(Data([1]))]), tokenProvider: { _ in "token" })

        let uploadMethod = try #require(sut.octoService.createImageUploadsAuthenticationMethods.first)
        let createMethod = try #require(sut.octoService.lastCreateBridgePostAuthenticationMethod)
        guard case let .authenticated(uploadToken, _) = uploadMethod,
              case let .authenticated(createToken, _) = createMethod else {
            Issue.record("Unexpected methods \(uploadMethod) and \(createMethod)")
            return
        }
        #expect(uploadToken == "fake_token")
        #expect(createToken == "rotated")
    }

    @Test func aBridgeImageUploadLostToTheNetworkFailsTheCreationWithNoNetwork() async throws {
        let sut = Sut(urlErrorCodes: [FakeImageUploadHTTPClient.url(0): .notConnectedToInternet])
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))

        do {
            _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
                content: Self.clientPost(medias: [.localImage(Data([1]))]), tokenProvider: { _ in "token" })
            Issue.record("The creation should have failed")
        } catch {
            guard case .serverCall(.noNetwork) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
        #expect(sut.octoService.lastCreateBridgePost == nil)
    }

    @Test func bridgeSignatureIsComputedOnTheClientsMedias() async throws {
        let sut = Sut()
        let original = try Self.largeJpeg()
        let content = Self.clientPost(medias: [.localImage(original)])
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))
        sut.injectBridgePostSuccess()
        let hashes = FingerprintRecorder()

        _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
            content: content,
            tokenProvider: { hash in
                await hashes.record(hash)
                return "token"
            })

        #expect(await hashes.values == [try content.getHashForSignature()])
        #expect(sut.octoService.lastCreateBridgePostClientToken == "token")
    }

    @Test func existingBridgePostUploadsNothing() async throws {
        let sut = Sut()
        sut.injectBridgePostSuccess() // the first `get` finds the post

        let post = try await sut.repository.getOrCreateClientObjectRelatedPost(
            content: Self.clientPost(medias: [.localImage(Data([1]))]), tokenProvider: { _ in "token" })

        #expect(post.id == "bridgeId")
        #expect(sut.octoService.createImageUploadsSizes.isEmpty)
        #expect(await sut.httpClient.puts.isEmpty)
        #expect(sut.octoService.lastCreateBridgePost == nil)
    }

    @Test func refusedBridgeUploadBecomesAFileValidationErrorWithItsIndex() async throws {
        let sut = Sut()
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.with {
            $0.fail = .with {
                $0.errors = [.with {
                    $0.message = "Empty photo"
                    $0.fileIndex = 1
                    $0.details = .emptyFile(.init())
                }]
            }
        })

        do {
            _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
                content: Self.clientPost(medias: [.localImage(Data([1])), .localImage(Data())]),
                tokenProvider: { _ in "token" })
            Issue.record("The creation should have been refused")
        } catch {
            guard case let .validation(validation) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            let fileErrors = try #require(validation.errors[.linkedToField(.file)])
            #expect(fileErrors.first?.imageIndex == 1)
            #expect(fileErrors.first?.localizedMessage == "Empty photo")
            guard case .emptyFile? = fileErrors.first?.detail else {
                Issue.record("Unexpected detail \(String(describing: fileErrors.first?.detail))")
                return
            }
        }
        #expect(sut.octoService.lastCreateBridgePost == nil)
    }

    /// The upload checks the token and the bridge availability before the creation does: its refusal is displayed as
    /// the creation's, the token errors in an alert, the unavailable bridge on the client object.
    @Test(arguments: [
        (Com_Octopuscommunity_CreateImageUploadsResponse.Error.OneOf_Details.invalidClientToken(.init()),
         GetOrCreateClientPost.ErrorDetail.invalidClientToken, ValidationErrors<GetOrCreateClientPost.Field,
         GetOrCreateClientPost.ErrorDetail>.DisplayKind.alert),
        (.expiredClientToken(.init()), .expiredClientToken, .alert),
        (.bridgePostUnavailable(.init()), .bridgePostUnavailable, .linkedToField(.clientObject))
    ])
    func refusedBridgeUploadKeepsTheCreationsTokenErrors(
        details: Com_Octopuscommunity_CreateImageUploadsResponse.Error.OneOf_Details,
        expectedDetail: GetOrCreateClientPost.ErrorDetail,
        expectedDisplay: ValidationErrors<GetOrCreateClientPost.Field, GetOrCreateClientPost.ErrorDetail>.DisplayKind
    ) async throws {
        let sut = Sut()
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.with {
            $0.fail = .with {
                $0.errors = [.with {
                    $0.message = "Refused"
                    $0.details = details
                }]
            }
        })

        do {
            _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
                content: Self.clientPost(medias: [.localImage(Data([1]))]),
                tokenProvider: { _ in "token" })
            Issue.record("The creation should have been refused")
        } catch {
            guard case let .validation(validation) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(validation.errors.count == 1)
            let errors = try #require(validation.errors[expectedDisplay])
            #expect(errors.map(\.detail) == [expectedDetail])
            #expect(errors.first?.localizedMessage == "Refused")
        }
        #expect(sut.octoService.lastCreateBridgePost == nil)
    }

    @Test func aFailedBridgeUploadFailsTheCreationWithoutCreateBridgePost() async throws {
        let sut = Sut(statuses: [FakeImageUploadHTTPClient.url(0): 500])
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 1))

        do {
            _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
                content: Self.clientPost(medias: [.localImage(Data([1]))]), tokenProvider: { _ in "token" })
            Issue.record("The creation should have failed")
        } catch {
            guard case .serverCall(.other) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
        #expect(sut.octoService.lastCreateBridgePost == nil)
    }

    @Test func bridgeCreateErrorCarriesItsImageIndex() async throws {
        let sut = Sut()
        sut.injectBridgePostNotFound()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))
        sut.octoService.injectNextGetOrCreateBridgePostResponse(.with {
            $0.result = .fail(.with {
                $0.errors = [.with {
                    $0.message = "Bad format"
                    $0.field = .contentFile
                    $0.fileIndex = 1
                    $0.details = .badFileFormat(.init())
                }]
            })
        })

        do {
            _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
                content: Self.clientPost(medias: [.localImage(Data([1])), .localImage(Data([2]))]),
                tokenProvider: { _ in "token" })
            Issue.record("The creation should have been refused")
        } catch {
            guard case let .validation(validation) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(validation.errors[.linkedToField(.file)]?.first?.imageIndex == 1)
        }
    }

    // MARK: - Deprecated single-call bridge path

    /// The public layer lets a single media reach this path (`validateMediaCountWithoutTokenProvider`): the backend
    /// takes one image inline.
    @Test func deprecatedGetOrCreateStillSendsBytes() async throws {
        let sut = Sut()
        sut.injectBridgePostSuccess()

        _ = try await sut.repository.getOrCreateClientObjectRelatedPost(
            content: Self.clientPost(medias: [.localImage(Data([1]))]))

        #expect(sut.octoService.createImageUploadsSizes.isEmpty)
        #expect(await sut.httpClient.puts.isEmpty)
        let sent = try #require(sut.octoService.lastGetOrCreateBridgePost).media.images
        #expect(sent.map(\.file) == [.bytes(Data([1]))])
    }

    // MARK: - Helpers

    private static func clientPost(medias: [ClientPost.Attachment]) -> ClientPost {
        ClientPost(clientObjectId: "clientObjectId", groupId: "Sport", text: "Some text for the bridge post",
                   catchPhrase: nil, medias: medias, viewClientObjectButtonText: nil)
    }

    /// A small PNG with a transparent area: the resizer keeps it a PNG and reports it as not compressed.
    private static func transparentPng() throws -> Data {
        let size = CGSize(width: 40, height: 40)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 40))
        }
    }

    /// A JPEG larger than the resizer's maximum size, so that resizing changes its bytes.
    private static func largeJpeg() throws -> Data {
        let size = CGSize(width: 2_000, height: 1_000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 1) { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 100, y: 100, width: 800, height: 300))
        }
    }
}

// MARK: - Sut

private struct Sut {
    let repository: PostsRepository
    let octoService: MockOctoService
    let httpClient: FakeImageUploadHTTPClient
    let authProvider: MockAuthenticatedCallProvider

    init(statuses: [URL: Int] = [:], urlErrorCodes: [URL: URLError.Code] = [:]) {
        let httpClient = FakeImageUploadHTTPClient(statuses: statuses, urlErrorCodes: urlErrorCodes)
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }
        injector.register { _ in Validators(appManagedFields: []) }
        injector.register { _ in httpClient }
        injector.register { ImageUploadsService(injector: $0) }
        injector.registerMocks(.remoteClient, .authProvider, .networkMonitor, .blockedUserIdsProvider,
                               .configRepository, .appStateMonitor)

        self.httpClient = httpClient
        repository = PostsRepository(injector: injector)
        authProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
            as! MockAuthenticatedCallProvider
        octoService = injector.getInjected(identifiedBy: Injected.remoteClient).octoService as! MockOctoService
    }

    /// The next `put(post:)` succeeds, and so does the `getBatch` that follows it.
    func injectPutPostSuccess() {
        octoService.injectNextPutPostResponse(.with {
            $0.result = .success(.with {
                $0.post = .with {
                    $0.createdAt = Date().timestampMs
                    $0.id = "newPost"
                    $0.parentID = "topicId"
                    $0.createdBy = .with {
                        $0.profileID = "me"
                        $0.nickname = "Me"
                    }
                    $0.content = .with { $0.post = .with { $0.text = "Sent" } }
                }
            })
        })
        octoService.injectNextGetBatchResponse(.with {
            $0.responses = [.with {
                $0.octoObjectID = "newPost"
                $0.requesterCtx = .with {
                    $0.canAccess = true
                    $0.canCreateChildren = true
                }
            }]
        })
    }

    /// The next bridge call answers that the post does not exist.
    func injectBridgePostNotFound() {
        octoService.injectNextGetOrCreateBridgePostResponse(.with {
            $0.result = .fail(.with {
                $0.errors = [.with {
                    $0.message = "Post not found"
                    $0.field = .contentClientObject
                    $0.details = .postNotFound(.init())
                }]
            })
        })
    }

    /// The next bridge call answers with the bridge post.
    func injectBridgePostSuccess() {
        octoService.injectNextGetOrCreateBridgePostResponse(.with {
            $0.result = .success(.with {
                $0.postBridge = .with {
                    $0.createdAt = Date().timestampMs
                    $0.id = "bridgeId"
                    $0.parentID = "Sport"
                    $0.createdBy = .with {
                        $0.profileID = "authorId"
                        $0.nickname = ""
                    }
                    $0.content = .with { $0.post = .with { $0.text = "Some text for the bridge post" } }
                }
            })
        })
    }
}

private actor FingerprintRecorder {
    private(set) var values = [String]()

    func record(_ value: String) {
        values.append(value)
    }
}
