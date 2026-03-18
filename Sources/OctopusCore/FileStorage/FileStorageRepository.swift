//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

public enum OctopusFileStorageProvider {
    public static let cachedFolder = (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
                                      FileManager.default.temporaryDirectory)
        .appendingPathComponent("OctopusSDK")

    static func clearCachedFolder() throws {
        guard FileManager.default.fileExists(atPath: cachedFolder.path) else { return }
        try FileManager.default.removeItem(at: cachedFolder)
    }
}
