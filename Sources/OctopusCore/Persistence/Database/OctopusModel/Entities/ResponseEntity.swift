//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(ResponseEntity)
class ResponseEntity: OctoObjectEntity {
    @NSManaged public var text: String?
    @NSManaged public var translatedText: String?
    @NSManaged public var originalLanguage: String?
    @NSManaged public var mediasRelationship: NSOrderedSet

    var medias: [MediaEntity] {
        mediasRelationship.array as? [MediaEntity] ?? []
    }

    func fill(with response: StorableResponse, context: NSManagedObjectContext) throws {
        try super.fill(with: response, context: context)
        text = response.text?.originalText
        translatedText = response.text?.translatedText
        originalLanguage = response.text?.originalLanguage
        mediasRelationship = NSOrderedSet(array: response.medias.map {
            let mediaEntity = MediaEntity(context: context)
            mediaEntity.url = $0.url
            mediaEntity.type = $0.kind.entity.rawValue
            mediaEntity.width = $0.size.width
            mediaEntity.height = $0.size.height
            return mediaEntity
        })
    }
}
