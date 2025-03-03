//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

extension Compat {
    // TODO: use @StateObject directly on iOS14+
    /// State object compatibility for iOS 13. Backed by an ObservableObject.
    @MainActor
    @propertyWrapper struct StateObject<Wrapped: ObservableObject>: @preconcurrency DynamicProperty {
        private final class Wrapper: ObservableObject {
            private var subject = PassthroughSubject<Void, Never>()

            var value: Wrapped? {
                didSet {
                    cancellable = nil
                    cancellable = value?.objectWillChange
                        .sink { [subject] _ in subject.send() }
                }
            }

            private var cancellable: AnyCancellable?

            var objectWillChange: AnyPublisher<Void, Never> {
                subject.eraseToAnyPublisher()
            }
        }

        @State private var state = Wrapper()

        @ObservedObject private var observedObject = Wrapper()

        private var factory: () -> Wrapped

        var wrappedValue: Wrapped {
            if let object = state.value {
                return object
            } else {
                let object = factory()
                state.value = object
                return object
            }
        }

        var projectedValue: ObservedObject<Wrapped>.Wrapper {
            ObservedObject(wrappedValue: wrappedValue).projectedValue
        }

        init(wrappedValue factory: @autoclosure @escaping () -> Wrapped) {
            self.factory = factory
        }

        mutating func update() {
            if state.value == nil {
                state.value = factory()
            }
            if observedObject.value !== state.value {
                observedObject.value = state.value
            }
        }
    }
}
