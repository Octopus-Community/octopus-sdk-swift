//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Sheet-style screen presented from the Account tab when the user wants to edit the
/// entitlements of the currently connected user.
struct EditEntitlementsScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObjectCompat private var viewModel = EditEntitlementsViewModel()

    @State private var errorAlertPresented = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pick the entitlements you want to claim. Saving will mint a fresh JWT and refresh the SDK.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
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
                        Text(viewModel.isSaving ? "Saving…" : "Save & refresh")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                .disabled(viewModel.isSaving)
            }
            .padding()
            .navigationBarTitle("Edit entitlements", displayMode: .inline)
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
