//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

/// A cached image that has two urls: one for the dark and one for the light mode
struct AsyncCachedDynamicImage<Content: View, Placeholder: View>: View {
    @Environment(\.colorScheme) var colorScheme

    let urls: DarkLightValue<URL>
    let cache: ImageCache
    let croppingRatio: Double?
    let placeholder: () -> Placeholder
    let content: (CachedImage) -> Content

    init(urls: DarkLightValue<URL>, cache: ImageCache,
         croppingRatio: Double? = nil,
         @ViewBuilder placeholder: @escaping () -> Placeholder = { EmptyView() },
         @ViewBuilder content: @escaping (CachedImage) -> Content) {
        self.urls = urls
        self.cache = cache
        self.croppingRatio = croppingRatio
        self.placeholder = placeholder
        self.content = content
    }

    var body: some View {
        AsyncCachedImage(
            url: colorScheme == .dark ? urls.darkValue : urls.lightValue,
            cache: cache,
            croppingRatio: croppingRatio,
            placeholder: placeholder,
            content: content
        )
    }
}
