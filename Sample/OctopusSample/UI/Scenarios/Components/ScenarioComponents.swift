//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

// The design-system pieces the Scenarios list and the scenario screens share, measured on the Android sample.

extension View {
    /// Sets the QA test id when there is one.
    @ViewBuilder
    func accessibilityId(ifPresent identifier: String?) -> some View {
        if let identifier {
            accessibilityId(identifier)
        } else {
            self
        }
    }
}

/// The filled pill: `buttonBackground` ground, `buttonText` label, 48 pt high.
struct PrimaryPillButton: View {
    let title: String
    var systemImage: String?
    var isLoading = false
    var isEnabled = true
    var testId: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PillLabel(title: title, systemImage: systemImage, isLoading: isLoading,
                      ink: SampleTokens.Colors.buttonText)
                .background(Capsule().fill(SampleTokens.Colors.buttonBackground))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityId(ifPresent: testId)
    }
}

/// The outlined pill: same shape as `PrimaryPillButton`, a 1 pt outline on the screen ground.
struct SecondaryPillButton: View {
    let title: String
    var systemImage: String?
    var isLoading = false
    var isEnabled = true
    var testId: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PillLabel(title: title, systemImage: systemImage, isLoading: isLoading,
                      ink: SampleTokens.Colors.accentText)
                .overlay(Capsule().strokeBorder(SampleTokens.Colors.outline, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityId(ifPresent: testId)
    }
}

private struct PillLabel: View {
    let title: String
    let systemImage: String?
    let isLoading: Bool
    let ink: Color

    var body: some View {
        HStack(spacing: SampleTokens.Spacing.space2) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ink))
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
            }
            Text(title)
                .font(SampleTokens.Typography.buttonLabel)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(ink)
        .frame(maxWidth: .infinity, minHeight: SampleTokens.Size.buttonHeight)
        .padding(.horizontal, SampleTokens.Spacing.space6)
    }
}

/// A preset button of a scenario: the filled pill for the one that matches the applied state, the outlined one
/// otherwise.
struct ModeButton: View {
    let title: String
    var isSelected = false
    var isEnabled = true
    var isLoading = false
    let testId: String
    let action: () -> Void

    var body: some View {
        if isSelected {
            PrimaryPillButton(title: title, isLoading: isLoading, isEnabled: isEnabled, testId: testId,
                              action: action)
        } else {
            SecondaryPillButton(title: title, isLoading: isLoading, isEnabled: isEnabled, testId: testId,
                                action: action)
        }
    }
}

/// The titled `extraLarge` block. The "Try it" tone is an `accentTint` ground with a 1 pt `accentText` edge at
/// 35 %; the default tone is a card on `surface`.
struct ScenarioBlock<Content: View>: View {
    let title: String
    var systemImage: String?
    var tryTone = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            HStack(spacing: SampleTokens.Spacing.space2) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: SampleTokens.Size.iconSmall * 0.8, weight: .semibold))
                        .foregroundColor(SampleTokens.Colors.accentText)
                }
                Text(title)
                    .font(SampleTokens.Typography.buttonLabel)
                    .foregroundColor(SampleTokens.Colors.text)
            }
            .frame(maxWidth: .infinity, minHeight: SampleTokens.Size.touchMin, alignment: .leading)
            content()
        }
        .padding(.horizontal, SampleTokens.Spacing.space4)
        .padding(.top, SampleTokens.Spacing.space1)
        .padding(.bottom, SampleTokens.Spacing.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SampleTokens.Radius.extraLarge, style: .continuous)
                .fill(tryTone ? SampleTokens.Colors.accentTint : SampleTokens.Colors.surface))
        .overlay(
            RoundedRectangle(cornerRadius: SampleTokens.Radius.extraLarge, style: .continuous)
                .strokeBorder(tryTone ? SampleTokens.Colors.accentText.opacity(0.35) : SampleTokens.Colors.hairline,
                              lineWidth: 1))
    }
}

/// Monospace tag naming the SDK symbol a row or a scenario stands for.
struct ApiPill: View {
    let name: String

    var body: some View {
        Text(name)
            .font(SampleTokens.Typography.monoSmall)
            .foregroundColor(SampleTokens.Colors.accentText)
            .lineLimit(1)
            .padding(.horizontal, SampleTokens.Spacing.space2)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: SampleTokens.Radius.small, style: .continuous)
                    .fill(SampleTokens.Colors.accentTint))
    }
}

/// Monospace tag naming a parameter type.
struct TypePill: View {
    let name: String

    var body: some View {
        Text(name)
            .font(SampleTokens.Typography.monoSmall)
            .foregroundColor(SampleTokens.Colors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, SampleTokens.Spacing.space2)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: SampleTokens.Radius.small, style: .continuous)
                    .fill(SampleTokens.Colors.surface3))
            .overlay(
                RoundedRectangle(cornerRadius: SampleTokens.Radius.small, style: .continuous)
                    .strokeBorder(SampleTokens.Colors.outline, lineWidth: 1))
    }
}

/// The count of scenarios a section holds, next to its title.
struct CountPill: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(SampleTokens.Typography.badgeLabel)
            .foregroundColor(SampleTokens.Colors.onAccentContainer)
            .padding(.horizontal, SampleTokens.Spacing.space2)
            .padding(.vertical, 2)
            .background(Capsule().fill(SampleTokens.Colors.accentContainer))
    }
}

/// The arguments the scenario's call takes: name, type, and where the value comes from.
struct ScenarioParametersBlock: View {
    let parameters: [ScenarioParameter]

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            Text("Parameters")
                .font(SampleTokens.Typography.label)
                .foregroundColor(SampleTokens.Colors.text)
            ForEach(parameters, id: \.name) { parameter in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SampleTokens.Spacing.space2) {
                        Text(parameter.name)
                            .font(SampleTokens.Typography.mono.weight(.semibold))
                            .foregroundColor(SampleTokens.Colors.text)
                        TypePill(name: parameter.type)
                    }
                    Text(parameter.value)
                        .font(SampleTokens.Typography.callout)
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(SampleTokens.Spacing.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SampleTokens.Radius.large, style: .continuous)
                .fill(SampleTokens.Colors.surface))
        .overlay(
            RoundedRectangle(cornerRadius: SampleTokens.Radius.large, style: .continuous)
                .strokeBorder(SampleTokens.Colors.hairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityId("scenario-parameters")
    }
}

/// The raw outcome of the last call: a status badge, then the code block. Printed raw on purpose: an integrator
/// wants the shape the SDK returned, not a sentence written over it.
struct CodeResultBlock: View {
    let call: ScenarioCall
    var testId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            ResultStatusBadge(isError: call.isError, durationMs: call.durationMs)
            Text(call.result ?? "")
                .font(SampleTokens.Typography.mono)
                .foregroundColor(SampleTokens.Colors.codeText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SampleTokens.Spacing.space3)
                .background(
                    RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous)
                        .fill(SampleTokens.Colors.codeBackground))
                .textSelectionIfAvailable()
                .accessibilityId(ifPresent: testId)
        }
    }

    /// "Success · 124 ms", "Failure".
    static func badgeLabel(isError: Bool, durationMs: Int?) -> String {
        let word = isError ? "Failure" : "Success"
        guard let durationMs else { return word }
        return "\(word) · \(durationMs) ms"
    }
}

private struct ResultStatusBadge: View {
    let isError: Bool
    let durationMs: Int?

    var body: some View {
        let ink = isError ? SampleTokens.Colors.danger : SampleTokens.Colors.successText
        HStack(spacing: SampleTokens.Spacing.space1) {
            Image(systemName: isError ? "xmark" : "checkmark")
                .font(.system(size: 12, weight: .bold))
            Text(CodeResultBlock.badgeLabel(isError: isError, durationMs: durationMs))
                .font(SampleTokens.Typography.badgeLabel)
        }
        .foregroundColor(ink)
        .padding(.leading, SampleTokens.Spacing.space2)
        .padding(.trailing, 10)
        .frame(height: SampleTokens.Size.badgeHeight)
        .background(Capsule().fill(isError ? SampleTokens.Colors.dangerTint : SampleTokens.Colors.successTint))
        .overlay(Capsule().strokeBorder(ink, lineWidth: 1.5))
    }
}

private extension View {
    @ViewBuilder
    func textSelectionIfAvailable() -> some View {
        if #available(iOS 15.0, *) {
            textSelection(.enabled)
        } else {
            self
        }
    }
}

/// Three pulsing bars on the code ground while a call runs.
struct ResultSkeleton: View {
    @State private var dimmed = true

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            ForEach([0.45, 0.8, 0.6], id: \.self) { fraction in
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(dimmed ? 0.35 : 0.7))
                        .frame(width: proxy.size.width * fraction)
                }
                .frame(height: 10)
            }
        }
        .padding(SampleTokens.Spacing.space3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SampleTokens.Colors.codeBackground))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { dimmed = false }
        }
        .accessibilityId("scenario-result-skeleton")
    }
}

/// "● Override active · …": what the scenario last applied, when the SDK has no getter for it.
struct OverrideActiveBadge: View {
    let label: String
    var testId: String?

    var body: some View {
        Text("● \(label)")
            .font(SampleTokens.Typography.badgeLabel)
            .foregroundColor(SampleTokens.Colors.accentText)
            .padding(.horizontal, SampleTokens.Spacing.space3)
            .padding(.vertical, 6)
            .background(Capsule().fill(SampleTokens.Colors.accentTint))
            .overlay(Capsule().strokeBorder(SampleTokens.Colors.accentText.opacity(0.35), lineWidth: 1))
            .accessibilityId(ifPresent: testId)
    }
}

/// The one-paragraph intro above a scenario's presets.
struct SectionIntro: View {
    let text: String

    var body: some View {
        Text(text)
            .font(SampleTokens.Typography.callout)
            .foregroundColor(SampleTokens.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A heading inside a scenario's controls.
struct ControlsHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(SampleTokens.Typography.label)
            .foregroundColor(SampleTokens.Colors.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The read-only state of the section's feature toggle, with the way back to the switch. `onChange` is nil when
/// this build cannot act on the switch: "Change" would only lead to a disabled control, so it is not offered.
struct FeatureStateLine: View {
    let text: String
    let onChange: (() -> Void)?

    var body: some View {
        HStack(spacing: SampleTokens.Spacing.space2) {
            Image(systemName: "info.circle")
                .font(.system(size: SampleTokens.Size.iconSmall * 0.85))
                .foregroundColor(SampleTokens.Colors.accentText)
            Text(text)
                .font(SampleTokens.Typography.callout)
                .foregroundColor(SampleTokens.Colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onChange {
                Button(action: onChange) {
                    Text("Change")
                        .font(SampleTokens.Typography.label)
                        .foregroundColor(SampleTokens.Colors.accentText)
                        .frame(minHeight: SampleTokens.Size.touchMin)
                }
                .buttonStyle(.plain)
                .accessibilityId("scenario-feature-state-change")
            }
        }
        // Same height with or without "Change".
        .frame(minHeight: SampleTokens.Size.touchMin)
        .padding(.leading, SampleTokens.Spacing.space3)
        .padding(.trailing, SampleTokens.Spacing.space2)
        .background(
            RoundedRectangle(cornerRadius: SampleTokens.Radius.large, style: .continuous)
                .fill(SampleTokens.Colors.accentTint))
        .overlay(
            RoundedRectangle(cornerRadius: SampleTokens.Radius.large, style: .continuous)
                .strokeBorder(SampleTokens.Colors.accentText.opacity(0.45), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityId("scenario-feature-state")
    }
}

/// The one-line outcome of a preset, hidden until there is one.
struct ScenarioResultLine: View {
    let text: String?
    var isError = false
    var testId: String?

    var body: some View {
        if let text {
            Text(text)
                .font(SampleTokens.Typography.caption)
                .foregroundColor(isError ? SampleTokens.Colors.danger : SampleTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityId(ifPresent: testId)
        }
    }
}

/// A value the SDK publishes, shown live with a green dot.
struct LiveFlowDisplay: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: SampleTokens.Spacing.space2) {
            Circle()
                .fill(SampleTokens.Colors.success)
                .frame(width: 6, height: 6)
            Text(label)
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.textSecondary)
            Spacer(minLength: SampleTokens.Spacing.space2)
            Text(value)
                .font(SampleTokens.Typography.monoSmall)
                .foregroundColor(SampleTokens.Colors.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, SampleTokens.Spacing.space3)
        .padding(.vertical, SampleTokens.Spacing.space2)
        .background(
            RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous)
                .fill(SampleTokens.Colors.accentTint))
    }
}

/// One SDK call: its signature, what it does, and the button that runs it.
struct ApiMethodCard: View {
    let name: String
    let description: String
    var isRunning = false
    var isEnabled = true
    let testId: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            Text(name)
                .font(SampleTokens.Typography.mono.weight(.semibold))
                .foregroundColor(SampleTokens.Colors.text)
            Text(description)
                .font(SampleTokens.Typography.callout)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryPillButton(title: isRunning ? "Running..." : "Execute", isLoading: isRunning,
                              isEnabled: isEnabled, testId: testId, action: action)
        }
        .padding(SampleTokens.Spacing.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SampleTokens.Radius.large, style: .continuous)
                .fill(SampleTokens.Colors.surface2))
    }
}

/// A text field in the scenario controls' style.
struct ScenarioTextField: View {
    let title: String
    var placeholder = ""
    @Binding var text: String
    let testId: String

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
            Text(title)
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.textSecondary)
            TextField(placeholder, text: $text)
                .font(SampleTokens.Typography.body)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, SampleTokens.Spacing.space3)
                .frame(minHeight: SampleTokens.Size.touchMin)
                .background(
                    RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous)
                        .fill(SampleTokens.Colors.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous)
                        .strokeBorder(SampleTokens.Colors.outline, lineWidth: 1))
                .accessibilityId(testId)
        }
    }
}

/// A navigation row inside a scenario, to the screen that holds the rest of its controls.
struct ScenarioLinkRow<Destination: View>: View {
    let title: String
    var subtitle: String?
    let testId: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: SampleTokens.Spacing.space3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SampleTokens.Typography.bodyStrong)
                        .foregroundColor(SampleTokens.Colors.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(SampleTokens.Typography.caption)
                            .foregroundColor(SampleTokens.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SampleTokens.Colors.textSecondary)
            }
            .padding(.horizontal, SampleTokens.Spacing.space3)
            .frame(minHeight: SampleTokens.Size.rowMin)
            .sampleCardSurface(cornerRadius: SampleTokens.Radius.large)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityId(testId)
    }
}
