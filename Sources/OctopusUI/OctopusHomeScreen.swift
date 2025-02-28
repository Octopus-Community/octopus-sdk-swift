//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import Combine

/// UI Entry point.
///
/// The `OctopusHomeScreen` displays the horizontally scrollable list of feeds on the top and the main feed as a
/// content.
///
/// This SwiftUI view contains a NavigationView, hence it should be not embedded in another Navigation object.
public struct OctopusHomeScreen: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    private let octopus: OctopusSDK

    
    /// Constructor of the `OctopusHomeScreen`.
    /// - Parameter octopus: The Octopus SDK
    ///
    /// You can pass an OctopusTheme as an environment to customize the colors, fonts and images used in this
    /// view:
    /// ```swift
    /// OctopusHomeScreen(octopus: octopus)
    ///     .environment(\.octopusTheme, appTheme)
    /// ```
    public init(octopus: OctopusSDK) {
        self.octopus = octopus

        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.configureWithTransparentBackground()
        coloredAppearance.backgroundColor = .systemBackground
        coloredAppearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]

        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
    }

    public var body: some View {
        NavigationView {
            if #available(iOS 14.0, *) {
                RootFeedsView(octopus: octopus)
                    .navigationBarItems(
                        leading: Image(uiImage: theme.assets.logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 28),
                        trailing:
                            Group {
                                if presentationMode.wrappedValue.isPresented {
                                    Button(action: {
                                        presentationMode.wrappedValue.dismiss()
                                    }) {
                                        Text("Common.Close", bundle: .module)
                                            .font(theme.fonts.navBarItem)
                                    }
                                }
                            }
                    )
                    .onAppear {
                        if presentationMode.wrappedValue.isPresented && !isPresentedModally {
                            print("⚠️ You are trying to push the OctopusHomeScreen from a screen that already has a " +
                                  "navigation bar.")
                        }
                    }
            } else {
                UnsupportedOSVersionView()
                    .navigationBarItems(
                        trailing:
                            Group {
                                if presentationMode.wrappedValue.isPresented {
                                    Button(action: {
                                        presentationMode.wrappedValue.dismiss()
                                    }) {
                                        Text("Common.Close", bundle: .module)
                                            .font(theme.fonts.navBarItem)
                                    }
                                }
                            }
                    )
            }
        }
        .accentColor(theme.colors.accent)
    }
}

private extension View {
    @MainActor
    var isPresentedModally: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else {
            return false
        }
        return window.rootViewController?.presentedViewController != nil
    }
}
