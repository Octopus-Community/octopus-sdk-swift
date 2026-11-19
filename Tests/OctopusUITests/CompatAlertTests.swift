//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit
import Testing
@testable import OctopusUI

/// The compat alerts, presented from a window.
@MainActor
struct CompatAlertTests {
    @Test func singleButtonAlertOffersOnlyOk() async throws {
        // The test host runs without scenes, so the window is attached to the screen directly.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: Color.clear
            .compatAlert("Content.Create.Picture.MaxReached.Formal", isPresented: .constant(true)))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        try await waitUntil { window.rootViewController?.presentedViewController is UIAlertController }
        let alert = try #require(window.rootViewController?.presentedViewController as? UIAlertController)
        defer { alert.dismiss(animated: false) }

        #expect(alert.title == NSLocalizedString("Content.Create.Picture.MaxReached.Formal", bundle: .module, comment: ""))
        #expect(alert.actions.map(\.title) == [NSLocalizedString("Common.Ok", bundle: .module, comment: "")])
    }
}
