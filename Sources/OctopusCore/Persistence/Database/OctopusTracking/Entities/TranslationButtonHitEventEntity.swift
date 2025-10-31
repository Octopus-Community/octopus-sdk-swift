//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(TranslationButtonHitEventEntity)
class TranslationButtonHitEventEntity: EventEntity {
    @NSManaged public var translationDisplayed: Bool
}
