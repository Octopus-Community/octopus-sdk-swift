import Foundation
import SwiftUI

@available(iOS, deprecated: 16.0, message: "Use SwiftUI's Navigation API beyond iOS 15")
/// A type-erased wrapper for an Array of any Hashable types, to be displayed in a `NBNavigationStack`.
struct NBNavigationPath: Equatable {
  var elements: [AnyHashable]

  /// The number of screens in the path.
  var count: Int { elements.count }

  /// WHether the path is empty.
  var isEmpty: Bool { elements.isEmpty }

  init(_ elements: [AnyHashable] = []) {
    self.elements = elements
  }

  init<S: Sequence>(_ elements: S) where S.Element: Hashable {
    self.init(elements.map { $0 as AnyHashable })
  }

  mutating func append<V: Hashable>(_ value: V) {
    elements.append(value)
  }

  mutating func removeLast(_ k: Int = 1) {
    elements.removeLast(k)
  }
}
