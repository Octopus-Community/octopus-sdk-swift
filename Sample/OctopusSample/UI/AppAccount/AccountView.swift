//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Settings › Account, the iOS twin of the Android sample's `AccountScreen`, in its order: who is signed in, the
/// SSO identity the sample signs its local JWT with, the entitlements the next token asks for next to the ones
/// the session carries, then the session actions and their outcome.
struct AccountView: View {
    @StateObjectCompat private var viewModel = AccountViewModel()
    @State private var customEntitlement = ""

    var body: some View {
        List {
            identitySection
            loginSection
            entitlementsSection
            sessionSection
        }
        .listStyle(.insetGrouped)
        .sampleListBackground()
        .navigationBarTitle("Account", displayMode: .inline)
        .accessibilityId("account-screen")
        .dismissedOnPushRouting($viewModel.isEditProfilePresented)
        .fullScreenCover(isPresented: $viewModel.isEditProfilePresented) {
            AppEditUserScreen()
        }
        .hostAppFooter()
    }

    // MARK: - Identity

    private var identitySection: some View {
        Section {
            HStack(spacing: SampleTokens.Spacing.space3) {
                Text(viewModel.initials)
                    .font(SampleTokens.Typography.headline)
                    .foregroundColor(SampleTokens.Colors.accentText)
                    .frame(width: SampleTokens.Size.avatarLarge, height: SampleTokens.Size.avatarLarge)
                    .background(Circle().fill(SampleTokens.Colors.accentTint))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
                    Text(viewModel.displayName)
                        .font(SampleTokens.Typography.bodyStrong)
                        .foregroundColor(SampleTokens.Colors.text)
                    Text(viewModel.appUser?.userId ?? "—")
                        .font(SampleTokens.Typography.caption)
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                }
                Spacer(minLength: SampleTokens.Spacing.space2)
                Text(viewModel.statusLabel)
                    .font(SampleTokens.Typography.label)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, SampleTokens.Spacing.space2)
                    .padding(.vertical, SampleTokens.Spacing.space1)
                    .background(Capsule().stroke(statusColor))
                    .accessibilityId("account-status")
            }
            .padding(.vertical, SampleTokens.Spacing.space2)
            .accessibilityElement(children: .combine)
            .accessibilityId("account-identity")
            .sampleRowSurface()

            if viewModel.isSignedIn {
                Button(action: { viewModel.isEditProfilePresented = true }, label: {
                    Label("Edit profile", systemImage: "pencil")
                        .font(SampleTokens.Typography.bodyStrong)
                        .foregroundColor(SampleTokens.Colors.accentText)
                })
                .accessibilityId("account-edit-profile-button")
                .sampleRowSurface()
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.statusLabel {
        case "Connected": return SampleTokens.Colors.successText
        case "Guest": return SampleTokens.Colors.warningText
        default: return SampleTokens.Colors.danger
        }
    }

    // MARK: - SSO login

    private var loginSection: some View {
        Section(
            header: Text("SSO login"),
            footer: Text("The identity the sample signs its local JWT with.")
        ) {
            TextField("User ID", text: $viewModel.userId)
                .textContentType(.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .accessibilityId("account-user-id-field")
                .sampleRowSurface()
            ChipFlow(spacing: SampleTokens.Spacing.space2) {
                ForEach(SampleUserIds.picker(storedUserId: viewModel.appUser?.userId), id: \.self) { id in
                    SampleChip(title: id, isSelected: viewModel.userId == id) { viewModel.userId = id }
                }
            }
            .padding(.vertical, SampleTokens.Spacing.space1)
            .accessibilityElement(children: .contain)
            .accessibilityId("account-user-id-chips")
            .sampleRowSurface()
            TextField("Nickname", text: $viewModel.nickname)
                .disableAutocorrection(true)
                .accessibilityId("account-nickname-field")
                .sampleRowSurface()
        }
    }

    // MARK: - Session

    private var sessionSection: some View {
        Section(header: Text("Session"), footer: messageFooter) {
            if viewModel.isSignedIn {
                actionRow(title: "Reconnect", systemImage: "arrow.triangle.2.circlepath",
                          help: "Re-creates the Octopus session with the updated entitlements.",
                          isBusy: viewModel.isConnecting, id: "account-reconnect-button") {
                    viewModel.connect()
                }
                actionRow(title: "Refresh entitlements", systemImage: "arrow.clockwise",
                          help: "Lighter SDK-side refresh, keeps the session.",
                          isBusy: viewModel.isRefreshing, id: "account-refresh-entitlements-button") {
                    Task { await viewModel.refreshEntitlements() }
                }
                actionRow(title: "Disconnect", systemImage: "rectangle.portrait.and.arrow.right",
                          help: nil, tint: SampleTokens.Colors.danger, id: "account-disconnect-button") {
                    Task { await viewModel.disconnect() }
                }
            } else {
                actionRow(title: "Connect SSO User", systemImage: "person.badge.plus",
                          help: "Forges a local JWT with these values and calls connectUser. " +
                          "No real identity server is contacted.",
                          isBusy: viewModel.isConnecting, id: "account-connect-button") {
                    viewModel.connect()
                }
            }
        }
    }

    @ViewBuilder
    private var messageFooter: some View {
        switch viewModel.message {
        case let .error(text):
            Text(text)
                .foregroundColor(SampleTokens.Colors.danger)
                .accessibilityId("account-error")
        case let .info(text):
            Text(text)
                .foregroundColor(SampleTokens.Colors.successText)
                .accessibilityId("account-message")
        case .none:
            EmptyView()
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func actionRow(title: String, systemImage: String, help: String?, isBusy: Bool = false,
                           tint: Color = SampleTokens.Colors.accentText, id: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action, label: {
            HStack(spacing: SampleTokens.Spacing.space3) {
                Image(systemName: systemImage)
                    .foregroundColor(tint)
                    .frame(width: SampleTokens.Size.icon)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
                    Text(title)
                        .font(SampleTokens.Typography.bodyStrong)
                        .foregroundColor(tint)
                    if let help {
                        Text(help)
                            .font(SampleTokens.Typography.caption)
                            .foregroundColor(SampleTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: SampleTokens.Spacing.space2)
                if isBusy { ProgressView() }
            }
            .frame(minHeight: SampleTokens.Size.rowMin - 2 * SampleTokens.Spacing.space1)
            .contentShape(Rectangle())
        })
        .disabled(isBusy)
        .accessibilityId(id)
        .sampleRowSurface()
    }

    // MARK: - Entitlements

    private var entitlementsSection: some View {
        Section(
            header: Text("Entitlements"),
            footer: Text("What this user is allowed to see and do in the community.")
        ) {
            ForEach(Entitlement.allCases) { entitlement in
                Toggle(isOn: Binding(get: { viewModel.entitlements.contains(entitlement) },
                                     set: { viewModel.setEntitlement(entitlement, on: $0) })) {
                    VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
                        HStack(spacing: SampleTokens.Spacing.space2) {
                            Text(entitlement.displayName)
                                .font(SampleTokens.Typography.bodyStrong)
                                .foregroundColor(SampleTokens.Colors.text)
                            if viewModel.isGranted(entitlement) {
                                Text("Granted")
                                    .font(SampleTokens.Typography.caption)
                                    .foregroundColor(SampleTokens.Colors.successText)
                            }
                        }
                        Text(entitlement.summary)
                            .font(SampleTokens.Typography.caption)
                            .foregroundColor(SampleTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(SampleTokens.Colors.accent)
                .accessibilityId("account-entitlement-\(entitlement.displayName.lowercased())")
                .sampleRowSurface()
            }
            if !viewModel.sortedCustomEntitlements.isEmpty {
                ChipFlow(spacing: 6) {
                    ForEach(viewModel.sortedCustomEntitlements, id: \.self) { value in
                        CustomEntitlementChip(value: value) { viewModel.removeCustomEntitlement(value) }
                    }
                }
                .padding(.vertical, SampleTokens.Spacing.space1)
                .accessibilityElement(children: .contain)
                .sampleRowSurface()
            }
            // Android's outlined field: "Custom entitlement" as the label, "e.g. customer:vip" as the placeholder.
            VStack(alignment: .leading, spacing: 2) {
                Text("Custom entitlement")
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .accessibilityHidden(true)
                HStack(spacing: SampleTokens.Spacing.space2) {
                    TextField("e.g. customer:vip", text: $customEntitlement, onCommit: commitCustomEntitlement)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .accessibilityLabelCompat("Custom entitlement")
                        .accessibilityId("account-custom-entitlement-field")
                    if !customEntitlement.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button(action: commitCustomEntitlement) {
                            Image(systemName: "plus")
                                .foregroundColor(SampleTokens.Colors.accentText)
                                .frame(width: SampleTokens.Size.icon, height: SampleTokens.Size.icon)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabelCompat("Add entitlement")
                        .accessibilityId("account-custom-entitlement-add")
                    }
                }
            }
            .padding(.vertical, SampleTokens.Spacing.space1)
            .sampleRowSurface()
            if viewModel.hasPendingEntitlementChange {
                Label("Pending — the current session still carries the previous set. Reconnect to apply.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.warningText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityId("account-entitlements-pending")
                    .sampleRowSurface()
            }
        }
        .accessibilityId("account-entitlements-card")
    }

    private func commitCustomEntitlement() {
        viewModel.addCustomEntitlement(customEntitlement)
        customEntitlement = ""
    }
}

/// A custom entitlement, with the cross that removes it from the next token.
private struct CustomEntitlementChip: View {
    let value: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: SampleTokens.Spacing.space1) {
            Text(value)
                .font(SampleTokens.Typography.callout)
                .foregroundColor(SampleTokens.Colors.accentText)
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(SampleTokens.Colors.accentText)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabelCompat("Remove \(value)")
        }
        .padding(.leading, SampleTokens.Spacing.space3)
        .padding(.trailing, SampleTokens.Spacing.space1)
        .frame(minHeight: SampleTokens.Size.chipHeight)
        .background(RoundedRectangle(cornerRadius: SampleTokens.Radius.medium).fill(SampleTokens.Colors.accentTint))
        .overlay(RoundedRectangle(cornerRadius: SampleTokens.Radius.medium)
            .strokeBorder(SampleTokens.Colors.accentText.opacity(0.35), lineWidth: 1))
    }
}
