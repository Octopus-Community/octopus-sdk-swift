//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

/// Where this build of the sample came from: the iOS twin of the Android "installed from Play Store" line. iOS
/// has no in-app update API, so the About card reports the source and offers no "Check for update".
enum SampleInstallSource: Equatable {
    case testFlight
    case appStore
    case development

    /// Reads the App Store receipt: TestFlight builds carry a sandbox receipt, store builds a production one, and
    /// a build installed from Xcode carries none.
    static func detect(receiptURL: URL?, fileExists: (String) -> Bool = FileManager.default.fileExists) -> Self {
        guard let receiptURL, fileExists(receiptURL.path) else { return .development }
        return receiptURL.lastPathComponent == "sandboxReceipt" ? .testFlight : .appStore
    }

    static var current: Self { detect(receiptURL: Bundle.main.appStoreReceiptURL) }

    var statusLine: String {
        switch self {
        case .testFlight: "Installed from TestFlight"
        case .appStore: "Installed from the App Store"
        case .development: "Not installed from TestFlight or the App Store"
        }
    }
}

/// Settings › About, mirroring the Android sample's `AboutScreen`: the App card, the versions, the licences of what
/// the sample links against, then the platform line. The design reference row is hidden, as on Android when its
/// URL is not configured.
struct AboutView: View {
    /// What the sample links against, with the licence each one ships under.
    static let licences: [(name: String, licence: String)] = [
        ("Octopus SDK", "Proprietary"),
        ("SwiftUI, UIKit and the other Apple frameworks", "Xcode and Apple SDKs Agreement"),
        ("gRPC Swift, SwiftNIO", "Apache-2.0"),
        ("Swift Protobuf", "Apache-2.0"),
        ("Swift Algorithms, Collections, Crypto, Log", "Apache-2.0"),
        ("KeychainAccess", "MIT"),
    ]

    private let installSource = SampleInstallSource.current

    var body: some View {
        List {
            Group {
                Section(header: SettingsSectionHeader(title: "App", subtitle: SettingsView.sampleVersionLine)) {
                    Text(installSource.statusLine)
                        .font(SampleTokens.Typography.callout)
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityId("sample-update-status")
                }
                Section(header: Text("Versions")) {
                    SettingsInfoRow(label: "App version",
                                    value: "\(SettingsView.sampleVersion) (\(SettingsView.sampleBuild))")
                    SettingsInfoRow(label: "SDK version", value: OctopusCore.version)
                }
                Section(header: SettingsSectionHeader(
                    title: "Licences", subtitle: "Open-source notices for what this sample links against.")) {
                    ForEach(Self.licences, id: \.name) { entry in
                        SettingsInfoRow(label: entry.name, value: entry.licence)
                    }
                }
                .accessibilityId("about-licences")
            }
            .sampleRowSurface()

            Section(footer: footer) { EmptyView() }
        }
        .listStyle(.insetGrouped)
        .sampleListBackground()
        .navigationBarTitle("About", displayMode: .inline)
        .accessibilityId("about-screen")
        .hostAppFooter()
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            Text("Built with the Octopus SDK for iOS")
                .font(SampleTokens.Typography.callout)
                .foregroundColor(SampleTokens.Colors.text)
            Text("iOS is a trademark or registered trademark of Cisco in the U.S. and other countries, used under " +
                 "license by Apple.")
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
