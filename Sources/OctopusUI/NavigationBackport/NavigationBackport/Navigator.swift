import SwiftUI

/// A navigator to use when the `NBNavigationStack` is initialized with a `NBNavigationPath` binding or no binding.`
typealias PathNavigator = Navigator<AnyHashable>

/// An object available via the environment that gives access to the current path.
/// Supports push and pop operations when `Screen` conforms to `NBScreen`.
@MainActor
class Navigator<Screen>: ObservableObject {
  var pathBinding: Binding<[Screen]>

  /// The current navigation path.
  var path: [Screen] {
    get { pathBinding.wrappedValue }
    set { pathBinding.wrappedValue = newValue }
  }

  init(_ pathBinding: Binding<[Screen]>) {
    self.pathBinding = pathBinding
  }
}
