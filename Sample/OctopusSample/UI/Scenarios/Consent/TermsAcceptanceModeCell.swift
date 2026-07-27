//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how a community can require explicit acceptance of its legal documents.
struct TermsAcceptanceModeCell: View {
    var body: some View {
        NavigationLink(destination: TermsAcceptanceModeView()) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Terms Acceptance")
                    Text("A community can require explicit acceptance of its legal documents via a " +
                         "consent sheet (one checkbox per document, or a single combined checkbox) " +
                         "at the first contribution, instead of the implicit legal footer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
