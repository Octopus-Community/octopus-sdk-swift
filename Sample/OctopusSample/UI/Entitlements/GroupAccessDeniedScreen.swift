//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

/// Full-screen presented when the SDK invokes the `groupAccessDeniedCallback`. Shows the
/// group name (looked up from the SDK's published `groups` list, falling back to the id),
/// explains why the user cannot enter, and lets them edit their entitlements + retry.
struct GroupAccessDeniedScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObjectCompat private var viewModel = EditEntitlementsViewModel()

    let groupId: String

    @State private var errorAlertPresented = false

    private var groupName: String {
        OctopusSDKProvider.instance.octopus?.groups
            .first(where: { $0.id == groupId })?.name ?? groupId
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: groupName)
                        .font(.system(size: 22, weight: .bold))
                    Text("This group is not accessible to your current entitlements. Adjust them below to gain access.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Divider()
                EditEntitlementsView(selection: Binding(
                    get: { viewModel.selection },
                    set: { newValue in
                        viewModel.selection = newValue
                        viewModel.markEdited()
                    }
                ))
                Spacer()
                Button(action: save) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(viewModel.isSaving ? "Saving…" : "Save & retry")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                .disabled(viewModel.isSaving)
            }
            .padding()
            .navigationBarTitle("Group not accessible", displayMode: .inline)
            .navigationBarItems(
                trailing:
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                    }
            )
            .modify {
                if #available(iOS 15.0, *) {
                    $0.alert(Text(verbatim: viewModel.errorMessage ?? ""),
                             isPresented: $errorAlertPresented,
                             actions: { Button("OK") { } })
                } else {
                    $0.alert(isPresented: $errorAlertPresented) {
                        Alert(title: Text(verbatim: viewModel.errorMessage ?? ""))
                    }
                }
            }
            .onValueChanged(of: viewModel.errorMessage) {
                errorAlertPresented = $0 != nil
            }
            .hostAppFooter()
        }
    }

    private func save() {
        Task {
            let success = await viewModel.save()
            if success {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
