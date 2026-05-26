//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

struct ProfileEntitlementsMappingTests {

    @Test func arrayMapsToSetWithDedup() {
        var proto = Com_Octopuscommunity_PrivateProfile()
        proto.entitlements = ["premium", "vip", "premium"]
        let storable = StorableCurrentUserProfile(from: proto, userId: "user-1")
        #expect(storable.entitlements == ["premium", "vip"])
    }

    @Test func emptyArrayMapsToEmptySet() {
        let proto = Com_Octopuscommunity_PrivateProfile()
        let storable = StorableCurrentUserProfile(from: proto, userId: "user-1")
        #expect(storable.entitlements.isEmpty)
    }
}
