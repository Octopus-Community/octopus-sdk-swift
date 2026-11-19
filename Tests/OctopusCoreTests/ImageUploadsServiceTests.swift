//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
import OctopusRemoteClient
import OctopusDependencyInjection
@testable import OctopusCore

struct ImageUploadsServiceTests {

    @Test func uploadsSendTheExactSizesAndBodies() async throws {
        let sut = Sut()
        let images = [Data(repeating: 1, count: 10), Data(repeating: 2, count: 2_048), Data(repeating: 3, count: 1)]
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 3))

        _ = try await sut.service.upload(images, authenticationMethod: .notAuthenticated)

        #expect(sut.octoService.createImageUploadsSizes == [[10, 2_048, 1]])
        let puts = await sut.httpClient.puts
        #expect(puts.count == 3)
        for (index, image) in images.enumerated() {
            let put = try #require(puts.first { $0.url == Sut.url(index) })
            #expect(put.body == image)
        }
    }

    @Test func uploadIdsKeepThePhotosOrderWhenPutsFinishOutOfOrder() async throws {
        let sut = Sut(delays: [Sut.url(0): 0.2, Sut.url(1): 0.1, Sut.url(2): 0])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 3))

        let ids = try await sut.service.upload(Sut.images(3), authenticationMethod: .notAuthenticated)

        #expect(ids == ["id0", "id1", "id2"])
    }

    @Test func neverMoreThanThreePutsInFlight() async throws {
        let sut = Sut(defaultDelay: 0.05)
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 7))

        let ids = try await sut.service.upload(Sut.images(7), authenticationMethod: .notAuthenticated)

        #expect(ids.count == 7)
        #expect(await sut.httpClient.maxInFlight == 3)
        #expect(await sut.httpClient.puts.count == 7)
    }

    @Test func refusalIsReportedWithTheServerErrors() async throws {
        let sut = Sut()
        let fail = Com_Octopuscommunity_CreateImageUploadsResponse.Fail.with {
            $0.errors = [.with {
                $0.message = "too big"
                $0.fileIndex = 2
                $0.details = .fileSizeTooBig(.init())
            }]
        }
        sut.octoService.injectNextCreateImageUploadsResponse(.with { $0.fail = fail })

        do {
            _ = try await sut.service.upload(Sut.images(3), authenticationMethod: .notAuthenticated)
            Issue.record("The upload should have been refused")
        } catch {
            guard case let .refused(refusal) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(refusal == fail)
            #expect(refusal.errors.first?.fileIndex == 2)
            #expect(refusal.errors.first?.message == "too big")
        }
        #expect(await sut.httpClient.puts.isEmpty)
    }

    @Test func aWindowOfThreeSlidesInsteadOfWaitingForTheWholeBatch() async throws {
        // Photo 0 is slow, the others are instant: with a sliding window, photo 3 starts as soon as photo 1 is done,
        // long before photo 0 finishes. With batches of 3 it would wait for photo 0.
        let sut = Sut(delays: [Sut.url(0): 0.3])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 4))

        _ = try await sut.service.upload(Sut.images(4), authenticationMethod: .notAuthenticated)

        let events = await sut.httpClient.events
        let startOf3 = try #require(events.firstIndex(of: .started(Sut.url(3))))
        let endOf0 = try #require(events.firstIndex(of: .finished(Sut.url(0))))
        #expect(startOf3 < endOf0)
    }

    @Test func aSuccessStatusIsAny2xx() async throws {
        let sut = Sut(statuses: [Sut.url(0): 200, Sut.url(1): 201, Sut.url(2): 204, Sut.url(3): 299])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 4))

        let ids = try await sut.service.upload(Sut.images(4), authenticationMethod: .notAuthenticated)

        #expect(ids == ["id0", "id1", "id2", "id3"])
    }

    @Test(arguments: [199, 300, 301, 404, 500])
    func aStatusOutside2xxFailsTheUpload(status: Int) async throws {
        let sut = Sut(statuses: [Sut.url(1): status])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))

        await expectUploadFailed(sut, images: Sut.images(2))
    }

    @Test func aFailedPutCancelsThePutsStillRunningAndStartsNoOtherOne() async throws {
        let sut = Sut(delays: [Sut.url(0): 0.05, Sut.url(1): 5, Sut.url(2): 5],
                      statuses: [Sut.url(0): 500])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 4))

        await expectUploadFailed(sut, images: Sut.images(4))

        let events = await sut.httpClient.events
        #expect(events.contains(.cancelled(Sut.url(1))))
        #expect(events.contains(.cancelled(Sut.url(2))))
        #expect(!events.contains(.started(Sut.url(3))))
        #expect(!events.contains(.finished(Sut.url(1))))
    }

    @Test func aRefusalWithoutAnyErrorIsAGenericFailure() async throws {
        let sut = Sut()
        sut.octoService.injectNextCreateImageUploadsResponse(.with { $0.fail = .init() })

        await expectUploadFailed(sut, images: Sut.images(1))
        #expect(await sut.httpClient.puts.isEmpty)
    }

    @Test func aFailedPutFailsTheUpload() async throws {
        let sut = Sut(statuses: [Sut.url(1): 403])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 3))

        await expectUploadFailed(sut, images: Sut.images(3))
    }

    @Test func aTransportErrorFailsTheUpload() async throws {
        let sut = Sut(failingUrls: [Sut.url(0)])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))

        await expectUploadFailed(sut, images: Sut.images(2))
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .networkConnectionLost, .timedOut,
                      .dataNotAllowed, .internationalRoamingOff,
                      .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost])
    func aConnectionLossDuringAPutIsReportedAsNoNetwork(code: URLError.Code) async throws {
        let sut = Sut(urlErrorCodes: [Sut.url(1): code])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 3))

        do {
            _ = try await sut.service.upload(Sut.images(3), authenticationMethod: .notAuthenticated)
            Issue.record("The upload should have failed")
        } catch {
            guard case .noNetwork = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
    }

    @Test(arguments: [URLError.Code.badServerResponse, .badURL, .cannotDecodeRawData])
    func anotherUrlErrorDuringAPutIsAGenericFailure(code: URLError.Code) async throws {
        let sut = Sut(urlErrorCodes: [Sut.url(0): code])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))

        await expectUploadFailed(sut, images: Sut.images(2))
    }

    @Test func aCancelledPutIsReportedAsCancelled() async throws {
        let sut = Sut(urlErrorCodes: [Sut.url(0): .cancelled])
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))

        await expectUploadCancelled(try await sut.service.upload(Sut.images(2), authenticationMethod: .notAuthenticated))
    }

    @Test func cancellingTheCallerDuringThePutsIsReportedAsCancelled() async throws {
        let sut = Sut(defaultDelay: 10)
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))
        let service = sut.service

        let upload = Task { try await service.upload(Sut.images(2), authenticationMethod: .notAuthenticated) }
        try await Task.sleep(nanoseconds: 100_000_000)
        upload.cancel()

        await expectUploadCancelled(try await upload.value)
    }

    @Test func aCancellationBecomesACancellationErrorOfTheAction() {
        let actionError: AuthenticatedInputActionError<String> = ImageUploadsService.Error.cancelled
            .asInputActionError { _ in "validation" }
        guard case let .serverCall(.other(error)) = actionError else {
            Issue.record("Unexpected error \(actionError)")
            return
        }
        #expect(error is CancellationError)
    }

    @Test func uploadsCountMismatchFails() async throws {
        let sut = Sut()
        sut.octoService.injectNextCreateImageUploadsResponse(.success(count: 2))

        await expectUploadFailed(sut, images: Sut.images(3))
        #expect(await sut.httpClient.puts.isEmpty)
    }

    @Test func anInvalidUrlFailsBeforeAnyPut() async throws {
        let sut = Sut()
        sut.octoService.injectNextCreateImageUploadsResponse(.with {
            $0.success = .with {
                $0.uploads = [
                    .with { $0.uploadID = "id0"; $0.uploadURL = Sut.url(0).absoluteString },
                    .with { $0.uploadID = "id1"; $0.uploadURL = "" }
                ]
            }
        })

        await expectUploadFailed(sut, images: Sut.images(2))
        #expect(await sut.httpClient.puts.isEmpty)
    }

    @Test func aResponseWithoutResultFails() async throws {
        let sut = Sut()
        sut.octoService.injectNextCreateImageUploadsResponse(.init())

        await expectUploadFailed(sut, images: Sut.images(1))
        #expect(await sut.httpClient.puts.isEmpty)
    }

    @Test func aFailedApiCallIsReportedAsAServerCallError() async throws {
        let sut = Sut()
        // No response injected: the mock throws.

        do {
            _ = try await sut.service.upload(Sut.images(1), authenticationMethod: .notAuthenticated)
            Issue.record("The upload should have failed")
        } catch {
            guard case .serverCall = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
        #expect(await sut.httpClient.puts.isEmpty)
    }

    @Test func noImageMakesNoCall() async throws {
        let sut = Sut()

        let ids = try await sut.service.upload([], authenticationMethod: .notAuthenticated)

        #expect(ids.isEmpty)
        #expect(sut.octoService.createImageUploadsSizes.isEmpty)
        #expect(await sut.httpClient.puts.isEmpty)
    }

    private func expectUploadCancelled(_ upload: @autoclosure () async throws -> [String]) async {
        do {
            _ = try await upload()
            Issue.record("The upload should have failed")
        } catch {
            guard let error = error as? ImageUploadsService.Error, case .cancelled = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
    }

    private func expectUploadFailed(_ sut: Sut, images: [Data]) async {
        do {
            _ = try await sut.service.upload(images, authenticationMethod: .notAuthenticated)
            Issue.record("The upload should have failed")
        } catch {
            guard case .uploadFailed = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
    }
}

// MARK: - Helpers

private struct Sut {
    let service: ImageUploadsService
    let octoService: MockOctoService
    let httpClient: FakeImageUploadHTTPClient

    init(defaultDelay: TimeInterval = 0, delays: [URL: TimeInterval] = [:], statuses: [URL: Int] = [:],
         failingUrls: Set<URL> = [], urlErrorCodes: [URL: URLError.Code] = [:]) {
        let httpClient = FakeImageUploadHTTPClient(
            defaultDelay: defaultDelay, delays: delays, statuses: statuses, failingUrls: failingUrls,
            urlErrorCodes: urlErrorCodes)
        let injector = Injector()
        injector.registerMocks(.remoteClient)
        injector.register { _ in httpClient }
        injector.register { ImageUploadsService(injector: $0) }
        self.httpClient = httpClient
        octoService = injector.getInjected(identifiedBy: Injected.remoteClient).octoService as! MockOctoService
        service = injector.getInjected(identifiedBy: Injected.imageUploadsService)
    }

    static func url(_ index: Int) -> URL { FakeImageUploadHTTPClient.url(index) }

    static func images(_ count: Int) -> [Data] {
        (0..<count).map { Data(repeating: UInt8($0), count: $0 + 1) }
    }
}
