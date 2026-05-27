//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Reusable checkbox list for picking entitlements. Stateless — the parent owns the
/// `Set<Entitlement>` via the binding.
struct EditEntitlementsView: View {
    @Binding var selection: Set<Entitlement>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Entitlement.allCases) { entitlement in
                Button(action: { toggle(entitlement) }) {
                    HStack(spacing: 12) {
                        Image(systemName: selection.contains(entitlement)
                              ? "checkmark.square.fill" : "square")
                            .foregroundColor(selection.contains(entitlement) ? .accentColor : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entitlement.displayName)
                                .foregroundColor(.primary)
                            Text(verbatim: entitlement.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ entitlement: Entitlement) {
        if selection.contains(entitlement) {
            selection.remove(entitlement)
        } else {
            selection.insert(entitlement)
        }
    }
}
