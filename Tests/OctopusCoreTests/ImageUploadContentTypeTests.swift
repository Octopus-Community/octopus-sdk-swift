//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

struct ImageUploadContentTypeTests {
    private static func bytes(_ string: String) -> [UInt8] { Array(string.utf8) }

    @Test func jpeg() {
        #expect(ImageUploadContentType.detect(from: Data([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10])) == "image/jpeg")
    }

    @Test func png() {
        #expect(ImageUploadContentType.detect(from: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])) == "image/png")
    }

    @Test func gif() {
        #expect(ImageUploadContentType.detect(from: Data(Self.bytes("GIF89a"))) == "image/gif")
        #expect(ImageUploadContentType.detect(from: Data(Self.bytes("GIF87a"))) == "image/gif")
    }

    @Test func webp() {
        let data = Data(Self.bytes("RIFF") + [0x24, 0, 0, 0] + Self.bytes("WEBPVP8 "))
        #expect(ImageUploadContentType.detect(from: data) == "image/webp")
    }

    @Test(arguments: ["heic", "heix", "hevc", "heim", "heis", "hevm", "hevs", "mif1", "msf1"])
    func heicBrands(brand: String) {
        let data = Data([0, 0, 0, 0x18] + Self.bytes("ftyp") + Self.bytes(brand) + [0, 0, 0, 0])
        #expect(ImageUploadContentType.detect(from: data) == "image/heic")
    }

    @Test func aRiffThatIsNotWebpIsUnknown() {
        let data = Data(Self.bytes("RIFF") + [0x24, 0, 0, 0] + Self.bytes("WAVEfmt "))
        #expect(ImageUploadContentType.detect(from: data) == "application/octet-stream")
    }

    @Test func anFtypWithAnotherBrandIsUnknown() {
        let data = Data([0, 0, 0, 0x18] + Self.bytes("ftyp") + Self.bytes("mp42") + [0, 0, 0, 0])
        #expect(ImageUploadContentType.detect(from: data) == "application/octet-stream")
    }

    @Test func unknownOrTooShortBytesFallBackToOctetStream() {
        #expect(ImageUploadContentType.detect(from: Data()) == "application/octet-stream")
        #expect(ImageUploadContentType.detect(from: Data([0xFF, 0xD8])) == "application/octet-stream")
        #expect(ImageUploadContentType.detect(from: Data([1, 2, 3, 4, 5])) == "application/octet-stream")
        #expect(ImageUploadContentType.detect(from: Data(Self.bytes("RIFF"))) == "application/octet-stream")
        let truncatedFtyp = Data([0, 0, 0, 0] + Self.bytes("ftyphe"))
        #expect(ImageUploadContentType.detect(from: truncatedFtyp) == "application/octet-stream")
    }
}
