//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 14, *)
struct NamespaceReader<Content: View, ID: Hashable>: View {
    @Environment(\.namespace) var namespace

    var content: Content

    var id: ID
    var anchor: UnitPoint = .center
    var isSource: Bool = true

    var body: some View {
        content
            .modify {
                if let namespace {
                    $0.matchedGeometryEffect(id: id, in: namespace, anchor: anchor, isSource: isSource)
                } else { $0 }
            }
    }
}

@available(iOS 14, *)
struct NamespaceWrapper<Content: View>: View {
    @Namespace var namespace

    var content: Content

    var body: some View {
        content.environment(\.namespace, namespace)
    }
}

@available(iOS 14, *)
struct NamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

@available(iOS 14, *)
extension EnvironmentValues {
    var namespace: Namespace.ID? {
        get {
            self[NamespaceKey.self]
        }
        set {
            self[NamespaceKey.self] = newValue
        }
    }
}

extension View {
    func namespaced() -> some View {
        if #available(iOS 14, *) {
            return NamespaceWrapper(content: self)
        } else {
            return self
        }
    }

    func namespacedMatchedGeometryEffect<ID>(
        id: ID, anchor: UnitPoint = .center, isSource: Bool = true) -> some View where ID : Hashable {
            if #available(iOS 14, *) {
                return NamespaceReader(content: self, id: id, anchor: anchor, isSource: isSource)
            } else {
                return self
            }
        }
}
