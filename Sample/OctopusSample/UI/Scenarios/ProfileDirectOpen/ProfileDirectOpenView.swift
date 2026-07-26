//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that shows how to open `OctopusProfileScreen` directly, either for the connected user or for
/// another user resolved from the host app's own clientUserId.
struct ProfileDirectOpenView: View {
    @StateObjectCompat private var viewModel = OctopusAuthSDKViewModel()

    @State private var clientUserId = ""
    @State private var displayOwnProfile = false
    @State private var displayProfileForClientUserId = false

    var body: some View {
        VStack(spacing: 16) {
            Button(action: { displayOwnProfile = true }) {
                HStack {
                    Image(systemName: "person.crop.circle")
                    Text("Open my profile")
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Open profile by clientUserId")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("clientUserId", text: $clientUserId)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Button(action: { displayProfileForClientUserId = true }) {
                    HStack {
                        Image(systemName: "person.fill.questionmark")
                        Text("Open profile")
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
                }
                .disabled(clientUserId.isEmpty)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            Spacer()
        }
        .padding()
        .navigationBarTitle(Text("Open Profile Directly"), displayMode: .inline)
        .onAppear {
            // Seed clientUserId once with the host app's own logged in user id (the "Unique
            // Identifier" set in the App Login Flow), so testers don't have to retype it. Never
            // overwrites a manual entry, and stays empty if no user is logged in.
            if clientUserId.isEmpty, let hostUserId = AppUserManager.instance.appUser?.userId {
                clientUserId = hostUserId
            }
        }
        .sheet(isPresented: $displayOwnProfile) {
            OctopusProfileScreen(octopus: viewModel.octopus)
        }
        .sheet(isPresented: $displayProfileForClientUserId) {
            OctopusProfileScreen(octopus: viewModel.octopus, clientUserId: clientUserId)
        }
        .hostAppFooter()
    }
}
