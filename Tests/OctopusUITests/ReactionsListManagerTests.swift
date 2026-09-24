//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import OctopusCore
@testable import OctopusUI

@MainActor
final class ReactionsListManagerTests: XCTestCase {

    /// Reproduces the crash this class caused on every OS below iOS 18.
    ///
    /// `ObservableObject`'s default `objectWillChange` reflects over every stored property to find the
    /// `@Published` ones. Resolving the metadata of a stored *function type* that carries a typed `throws`
    /// clause requires `swift_getExtendedFunctionTypeMetadata`, a runtime entry point that only exists in the
    /// iOS 18 runtime. Below that the weakly linked symbol is null and the process jumps to address 0 as soon
    /// as anything touches `objectWillChange` — which `@EnvironmentObject` and `Compat.StateObject` both do.
    ///
    /// Typed throws on a function *declaration* (such as `fetch(contentId:kind:cursor:pageSize:)`) is fine:
    /// only function *types* — typealiases, closure properties — are affected.
    func testObjectWillChangeCanBeBuilt() {
        _ = ReactionsListManager.forPreviews().objectWillChange
    }

    /// Catches a reintroduction of the crash above on modern simulators too, where the missing runtime entry
    /// point exists and `testObjectWillChangeCanBeBuilt` therefore cannot fail.
    func testNoStoredPropertyIsATypedThrowsFunctionType() {
        for child in Mirror(reflecting: ReactionsListManager.forPreviews()).children {
            let typeName = String(reflecting: type(of: child.value))
            XCTAssertFalse(
                typeName.contains("throws("),
                "`\(child.label ?? "?")` holds a typed-throws function type (\(typeName)), which crashes "
                + "ObservableObject reflection on every OS below iOS 18")
        }
    }
}
