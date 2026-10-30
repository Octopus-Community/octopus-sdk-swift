//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Testing
@testable import OctopusUI

@Suite
struct ZoomableImageSourceIDTests {
    private let url = URL(string: "https://example.com/image.jpg")!

    /// The same image drawn twice on a screen must give two matched geometry ids: two sources sharing an
    /// id give undefined results, and SwiftUI may leave one of the two frames empty.
    @Test func sameImageTwice_givesTwoDistinctIds() {
        let first = ZoomableImageSourceID(url: url, occurrence: UUID())
        let second = ZoomableImageSourceID(url: url, occurrence: UUID())

        #expect(first != second)
        #expect(Set([first, second]).count == 2)
    }

    @Test func sameOccurrence_keepsItsId() {
        let occurrence = UUID()

        #expect(ZoomableImageSourceID(url: url, occurrence: occurrence)
                == ZoomableImageSourceID(url: url, occurrence: occurrence))
    }

    @Test func onlyTheTappedOccurrenceIsZoomed() {
        let tapped = ZoomableImageSourceID(url: url, occurrence: UUID())
        let other = ZoomableImageSourceID(url: url, occurrence: UUID())
        let zoomed = ZoomableImageInfo(source: tapped, image: Image(systemName: "photo"))

        #expect(tapped.isZoomed(in: zoomed))
        #expect(!other.isZoomed(in: zoomed))
    }

    @Test func nothingZoomed_noOccurrenceIsZoomed() {
        let source = ZoomableImageSourceID(url: url, occurrence: UUID())

        #expect(!source.isZoomed(in: nil))
    }
}
