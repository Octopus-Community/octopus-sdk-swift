//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import UIKit
@testable import OctopusUI

@Suite
struct ImageThumbnailTests {
    @Test func squareImageNeedsTheSideOfTheSquare() {
        #expect(ImageThumbnail.maxPixelSize(filling: 660, imageSize: CGSize(width: 4000, height: 4000)) == 660)
    }

    @Test(arguments: [CGSize(width: 4000, height: 1000), CGSize(width: 1000, height: 4000)])
    func elongatedImageKeepsItsShortSideAtTheSideOfTheSquare(imageSize: CGSize) {
        #expect(ImageThumbnail.maxPixelSize(filling: 660, imageSize: imageSize) == 2640)
    }

    @Test func emptyImageSizeFallsBackToTheSideOfTheSquare() {
        #expect(ImageThumbnail.maxPixelSize(filling: 660, imageSize: .zero) == 660)
    }

    @Test func downsampleReducesTheLongestSide() throws {
        let data = CreatePostViewModelTests.pngData(width: 1000, height: 500)
        let thumbnail = try #require(ImageThumbnail.downsample(data, maxPixelSize: 200))
        #expect(thumbnail.size == CGSize(width: 200, height: 100))
    }

    @Test func downsampleNeverEnlarges() throws {
        let data = CreatePostViewModelTests.pngData(width: 100, height: 50)
        let thumbnail = try #require(ImageThumbnail.downsample(data, maxPixelSize: 400))
        #expect(thumbnail.size == CGSize(width: 100, height: 50))
    }

    @Test func downsampleOfNonImageDataIsNil() {
        #expect(ImageThumbnail.downsample(Data([0x00, 0x01, 0x02]), maxPixelSize: 200) == nil)
    }
}
