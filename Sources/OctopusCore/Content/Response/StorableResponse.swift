//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

protocol StorableResponse: StorableContent {
    var text: String? { get }
    var medias: [Media] { get }
}
