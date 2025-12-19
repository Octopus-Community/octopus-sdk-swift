//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct ProfileCounterView: View {
    @Environment(\.octopusTheme) private var theme
    
    let totalMessages: Int?
    let accountCreationDate: Date?

    var body: some View {
        if totalMessages != nil || accountCreationDate != nil {
            VStack(spacing: 0) {
                HStack(spacing: 80) {
                    if let totalMessages {
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: "\(totalMessages)")
                                .font(theme.fonts.body2)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.colors.gray900)
                            
                            Text(totalMessages > 1 ? "Profile.Detail.Message.Plural" : "Profile.Detail.Message.One",
                                 bundle: .module)
                            .font(theme.fonts.caption2)
                            .foregroundColor(theme.colors.gray900)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    
                    if let accountCreationDate {
                        HStack(spacing: 80) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(Seniority(from: accountCreationDate).localizedKey, bundle: .module)
                                    .font(theme.fonts.body2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.colors.gray900)
                                
                                Text("Profile.Detail.AccountAge", bundle: .module)
                                    .font(theme.fonts.caption2)
                                    .foregroundColor(theme.colors.gray900)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Spacer().frame(height: 16)
            }
        }
    }
}


