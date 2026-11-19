//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// The policy a banned account broke, displayed in a sheet: its name, its text as the community wrote it, and a
/// button to close.
struct CommunityAccessDeniedPolicyView: View {
    let policyName: String
    let policyDescription: String

    var body: some View {
        ContentSizedSheet(
            content: {
                PolicyContentView(policyName: policyName, policyDescription: policyDescription, scrolls: false)
            },
            scrollingContent: {
                PolicyContentView(policyName: policyName, policyDescription: policyDescription, scrolls: true)
            })
    }
}

private struct PolicyContentView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    let policyName: String
    let policyDescription: String
    /// Whether the text of the policy scrolls, when the sheet cannot be as high as its content.
    let scrolls: Bool

    var body: some View {
        VStack(spacing: 16) {
            if scrolls, #unavailable(iOS 16.0) {
                Capsule()
                    .fill(theme.colors.gray300)
                    .frame(width: 50, height: 8)
            }
            Text(verbatim: policyName)
                .font(theme.fonts.title2)
                .fontWeight(.semibold)
                .foregroundColor(theme.colors.gray900)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            if scrolls {
                ScrollView { descriptionText }
            } else {
                descriptionText
            }
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Text("Common.Close", bundle: .module)
                    .frame(minHeight: 28)
            }
            .buttonStyle(OctopusButtonStyle(.mid, style: .secondary, backgroundColor: theme.colors.gray200))
        }
        .padding(.top, 32)
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
    }

    /// The text as the community typed it: line breaks kept, nothing read as markdown.
    private var descriptionText: some View {
        Text(verbatim: policyDescription)
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.gray900)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Short") {
    CommunityAccessDeniedPolicyView(policyName: "Job applications", policyDescription: "No job offers here.")
}

#Preview("Long") {
    CommunityAccessDeniedPolicyView(
        policyName: "Job applications",
        policyDescription: Array(repeating: "We do not allow job applications in the community.", count: 60)
            .joined(separator: "\n"))
}
