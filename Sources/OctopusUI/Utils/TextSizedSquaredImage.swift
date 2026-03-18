//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct IconImage: View {
    let image: UIImage

    @State private var lineHeight: CGFloat = 24

    init(_ image: UIImage) {
        self.image = image
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: lineHeight, height: lineHeight)
            .clipped()
            .background(
                Text(verbatim: "x")
                    .fixedSize()
                    .readHeight($lineHeight)
                    .hidden()
            )
    }
}
