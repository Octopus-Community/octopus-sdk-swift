//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
import OctopusRemoteClient
@testable import OctopusCore

/// The `createImageUploads` call of `OctoService`, as the upload service sees it through the mock.
struct CreateImageUploadsRemoteCallTests {

    @Test func theInjectedResponseIsReturnedAndTheSizesAreRecordedInOrder() async throws {
        let octoService = MockOctoService()
        let response = Com_Octopuscommunity_CreateImageUploadsResponse.with {
            $0.success = .with {
                $0.uploads = [
                    .with { $0.uploadID = "upload-1"; $0.uploadURL = "https://example.com/1" },
                    .with { $0.uploadID = "upload-2"; $0.uploadURL = "https://example.com/2" }
                ]
            }
        }
        octoService.injectNextCreateImageUploadsResponse(response)

        let result = try await octoService.createImageUploads(
            sizes: [2_048, 512], bridge: nil, authenticationMethod: .notAuthenticated)

        #expect(result == response)
        #expect(octoService.createImageUploadsSizes == [[2_048, 512]])
    }

    @Test func callingWithoutAnInjectedResponseFails() async {
        let octoService = MockOctoService()

        await #expect(throws: RemoteClientError.self) {
            _ = try await octoService.createImageUploads(sizes: [1], bridge: nil, authenticationMethod: .notAuthenticated)
        }
        #expect(octoService.createImageUploadsSizes == [[1]])
    }
}
