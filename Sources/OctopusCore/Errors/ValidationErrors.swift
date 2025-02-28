//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

/// A generic list of form errors.
/// Field is indicating which field is impacted by a given error
/// ErrorDetail is a generic type indicating the detail of the error.
public struct ValidationErrors<Field: Sendable & Hashable, ErrorDetail: Sendable>: Error, Sendable {
    /// The way to display this kind of error
    public enum DisplayKind: Sendable, Hashable {
        /// The error should be displayed as an alert (i.e. not linked to a particular field)
        case alert
        /// The error should be displayed linked to the given field
        case linkedToField(Field)
    }

    /// An error on a form
    public struct Error: Sendable {
        /// The message to display to the user. This message is already localized.
        public let localizedMessage: String
        /// Detail of the error. This should be used only if a particular behavior is produced by this kind of error
        public let detail: ErrorDetail
    }

    /// Dictionary of errors indexed by the way to display them
    public let errors: [DisplayKind: [Error]]
}
