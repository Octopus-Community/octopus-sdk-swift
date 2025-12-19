//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    /// Communicates to the user what happens after performing the view's
    /// action.
    ///
    /// Provide a hint in the form of a brief phrase, like "Purchases the item"
    /// or "Downloads the attachment".
    func accessibilityHintInBundle(_ hint: LocalizedStringKey, bundle: Bundle = .module) -> some View {
        self
            .modify {
                if #available(iOS 14.0, *) {
                    $0.accessibilityHint(Text(hint, bundle: bundle))
                } else { $0 }
            }
    }

    /// Adds a label to the view that describes its contents.
    ///
    /// Use this method to provide an accessibility label for a view that doesn't display text, like an icon.
    /// For example, you could use this method to label a button that plays music with the text "Play".
    /// Don't include text in the label that repeats information that users already have. For example,
    /// don't use the label "Play button" because a button already has a trait that identifies it as a button.
    func accessibilityLabelInBundle(_ label: LocalizedStringKey?, bundle: Bundle = .module) -> some View {
        self
            .modify {
                if #available(iOS 14.0, *), let label {
                    $0.accessibilityLabel(Text(label, bundle: bundle))
                } else { $0 }
            }
    }

    /// Adds a label to the view that describes its contents.
    ///
    /// Use this method to provide an accessibility label for a view that doesn't display text, like an icon.
    /// For example, you could use this method to label a button that plays music with the text "Play".
    /// Don't include text in the label that repeats information that users already have. For example,
    /// don't use the label "Play button" because a button already has a trait that identifies it as a button.
    func accessibilityLabelCompat(_ value: String) -> some View {
        self
            .modify {
                if #available(iOS 14.0, *) {
                    $0.accessibilityLabel(value)
                } else { $0 }
            }
    }

    /// Adds the given traits to the view.
    @_disfavoredOverload
    func accessibilityAddTraits(_ traits: AccessibilityTraits) -> some View {
        self
            .modify {
                if #available(iOS 14.0, *) {
                    $0.accessibilityAddTraits(traits)
                } else { $0 }
            }
    }

    /// Adds a textual description of the value that the view contains.
    ///
    /// Use this method to describe the value represented by a view, but only if that's different than the
    /// view's label. For example, for a slider that you label as "Volume" using accessibilityLabelInBundle(),
    /// you can provide the current volume setting, like "60%", using accessibilityValue().
    func accessibilityValueInBundle(_ value: LocalizedStringKey, bundle: Bundle = .module) -> some View {
        self
            .modify {
                if #available(iOS 14.0, *) {
                    $0.accessibilityValue(Text(value, bundle: bundle))
                } else { $0 }
            }
    }

    /// Specifies whether to hide this view from system accessibility features.
    @_disfavoredOverload
    func accessibilityHidden(_ hidden: Bool) -> some View {
        self
            .modify {
                if #available(iOS 14.0, *) {
                    $0.accessibilityHidden(hidden)
                } else { $0 }
            }
    }

    /// Sets the sort priority order for this view's accessibility element,
    /// relative to other elements at the same level.
    ///
    /// Higher numbers are sorted first. The default sort priority is zero.
    @_disfavoredOverload
    func accessibilitySortPriority(_ sortPriority: Double) -> some View {
        self
            .modify {
                if #available(iOS 14.0, *) {
                    $0.accessibilitySortPriority(sortPriority)
                } else { $0 }
            }
    }
}
