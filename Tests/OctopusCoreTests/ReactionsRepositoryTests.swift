//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
@testable import OctopusCore

final class ReactionsRepositoryTests: XCTestCase {
    private var reactionsRepository: ReactionsRepository!
    private var mockOctoService: MockOctoService!
    private var injector: Injector!

    override func setUp() {
        injector = Injector()
        injector.registerMocks(.remoteClient, .networkMonitor, .authProvider)

        reactionsRepository = ReactionsRepository(injector: injector)
        mockOctoService = (injector.getInjected(identifiedBy: Injected.remoteClient).octoService as! MockOctoService)
    }

    // MARK: - Request

    func testAllTabSendsNoUnicodeAndNoCursor() async throws {
        injectPage([("p1", "❤️")], nextCursor: nil)

        _ = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: nil, cursor: nil, pageSize: 20)

        let request = try XCTUnwrap(mockOctoService.getReactionsPageRequests.first)
        XCTAssertEqual(request.parentID, "post-1")
        XCTAssertEqual(request.pageSize, 20)
        // Unset, not empty: an empty unicode would be a filter on the empty reaction kind.
        XCTAssertFalse(request.hasUnicode)
        XCTAssertFalse(request.hasPageCursor)
    }

    func testKindTabSendsItsUnicode() async throws {
        injectPage([("p1", "😂")], nextCursor: nil)

        _ = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: .joy, cursor: nil, pageSize: 20)

        let request = try XCTUnwrap(mockOctoService.getReactionsPageRequests.first)
        XCTAssertTrue(request.hasUnicode)
        XCTAssertEqual(request.unicode, "😂")
    }

    func testUnknownKindSendsItsRawUnicode() async throws {
        injectPage([("p1", "🦄")], nextCursor: nil)

        _ = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: .unknown("🦄"), cursor: nil, pageSize: 20)

        XCTAssertEqual(try XCTUnwrap(mockOctoService.getReactionsPageRequests.first).unicode, "🦄")
    }

    func testNextPageSendsTheCursorBack() async throws {
        injectPage([("p1", "❤️")], nextCursor: "cursor-1")
        injectPage([("p2", "❤️")], nextCursor: nil)

        let firstPage = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: nil, cursor: nil, pageSize: 20)
        _ = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: nil, cursor: firstPage.nextCursor, pageSize: 20)

        XCTAssertEqual(mockOctoService.getReactionsPageRequests.count, 2)
        XCTAssertFalse(mockOctoService.getReactionsPageRequests[0].hasPageCursor)
        XCTAssertEqual(mockOctoService.getReactionsPageRequests[1].pageCursor, "cursor-1")
    }

    func testNegativePageSizeIsClampedInsteadOfCrashing() async throws {
        injectPage([], nextCursor: nil)

        _ = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: nil, cursor: nil, pageSize: -1)

        // UInt32(-1) would trap, so the repository has to clamp before converting.
        XCTAssertEqual(try XCTUnwrap(mockOctoService.getReactionsPageRequests.first).pageSize, 0)
    }

    // MARK: - Response mapping

    func testMapsProfilesInResponseOrder() async throws {
        injectPage([("alice", "❤️"), ("bob", "😂")], nextCursor: nil)

        let page = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: nil, cursor: nil, pageSize: 20)

        XCTAssertEqual(page.reactions.count, 2)
        XCTAssertEqual(page.reactions[0].profile?.uuid, "alice")
        XCTAssertEqual(page.reactions[0].profile?.nickname, "alice-nick")
        XCTAssertEqual(page.reactions[0].kind, .heart)
        XCTAssertEqual(page.reactions[1].profile?.uuid, "bob")
        XCTAssertEqual(page.reactions[1].kind, .joy)
    }

    func testKeepsEntryWithoutProfileForDeletedOrBannedMember() async throws {
        mockOctoService.injectNextGetReactionsPageResponse(.with {
            $0.reactions = [
                .with { $0.unicode = "❤️" },  // no profile at all: deleted or banned
                .with {
                    $0.unicode = "😂"
                    $0.profile = .with { $0.profileID = "" }  // present but blank: same meaning
                }
            ]
        })

        let page = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: nil, cursor: nil, pageSize: 20)

        // The reactions still count, so the entries must survive as anonymous ones.
        XCTAssertEqual(page.reactions.count, 2)
        XCTAssertNil(page.reactions[0].profile)
        XCTAssertEqual(page.reactions[0].kind, .heart)
        XCTAssertNil(page.reactions[1].profile)
        XCTAssertEqual(page.reactions[1].kind, .joy)
    }

    func testMapsUnknownUnicodeToUnknownKind() async throws {
        injectPage([("p1", "🦄")], nextCursor: nil)

        let page = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: nil, cursor: nil, pageSize: 20)

        XCTAssertEqual(page.reactions.first?.kind, .unknown("🦄"))
    }

    func testAbsentNextCursorMeansLastPage() async throws {
        injectPage([("p1", "❤️")], nextCursor: nil)

        let page = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: nil, cursor: nil, pageSize: 20)

        XCTAssertNil(page.nextCursor)
    }

    func testEmptyNextCursorMeansLastPage() async throws {
        injectPage([("p1", "❤️")], nextCursor: "")

        let page = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: nil, cursor: nil, pageSize: 20)

        // An empty cursor sent back would restart the list from the top.
        XCTAssertNil(page.nextCursor)
    }

    func testEmptyPageIsNotAnError() async throws {
        injectPage([], nextCursor: nil)

        let page = try await reactionsRepository.fetchReactions(
            contentId: "post-1", kind: .cry, cursor: nil, pageSize: 20)

        XCTAssertTrue(page.reactions.isEmpty)
        XCTAssertNil(page.nextCursor)
    }

    // MARK: - Errors

    func testNoNetworkThrowsNoNetwork() async throws {
        let mockNetworkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
            as! MockNetworkMonitor
        mockNetworkMonitor.connectionAvailable = false

        do {
            _ = try await reactionsRepository.fetchReactions(
                contentId: "post-1", kind: nil, cursor: nil, pageSize: 20)
            XCTFail("Expected .noNetwork")
        } catch ServerCallError.noNetwork {
            // expected
        } catch {
            XCTFail("Expected .noNetwork, got \(error)")
        }
        // Nothing must reach the network when it is known to be down.
        XCTAssertTrue(mockOctoService.getReactionsPageRequests.isEmpty)
    }

    func testRemoteErrorIsMappedToServerError() async throws {
        // No response injected: the mock throws a RemoteClientError.
        do {
            _ = try await reactionsRepository.fetchReactions(
                contentId: "post-1", kind: nil, cursor: nil, pageSize: 20)
            XCTFail("Expected .serverError")
        } catch ServerCallError.serverError {
            // expected
        } catch {
            XCTFail("Expected .serverError, got \(error)")
        }
    }

    // MARK: - Helpers

    private func injectPage(_ reactions: [(profileId: String, unicode: String)], nextCursor: String?) {
        mockOctoService.injectNextGetReactionsPageResponse(.with { response in
            response.reactions = reactions.map { reaction in
                .with {
                    $0.unicode = reaction.unicode
                    $0.profile = .with {
                        $0.profileID = reaction.profileId
                        $0.nickname = "\(reaction.profileId)-nick"
                    }
                }
            }
            if let nextCursor { response.nextPageCursor = nextCursor }
        })
    }
}
