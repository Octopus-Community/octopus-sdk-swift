//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import SwiftUI
import UIKit
import Octopus

/// What the chrome of the fullscreen viewer shows, driven by the viewer controller.
@MainActor
final class FullscreenViewerChromeModel: ObservableObject {
    /// The index of the photo shown.
    @Published var index: Int
    /// The number of photos.
    @Published var count: Int
    /// False while the photo is zoomed: the chrome fades out to leave the whole screen to the photo.
    @Published var isChromeVisible = true
    /// Whether the last page change went toward the end.
    @Published var lastMoveForward = true
    /// The safe area of the viewer, read from UIKit: the dots ignore the safe area to cover the whole screen, and the
    /// insets SwiftUI reports to them inside their hosting controller are zero, which put them under the home
    /// indicator.
    @Published var safeAreaInsets: UIEdgeInsets = .zero

    /// The frame of the close button, in window coordinates. Not published: only the hit testing of the chrome reads
    /// it, to let the touches outside of the button through to the photos.
    var closeButtonFrameInWindow: CGRect = .zero

    /// The language the SDK overrides the device's with, if any.
    private let locale: Locale?

    init(index: Int, count: Int, locale: Locale?) {
        self.index = index
        self.count = count
        self.locale = locale
    }

    /// The « current / total » counter, only shown when there is more than one photo. Same text as the counter of the
    /// post's carousel.
    var counterText: String? {
        guard count > 1 else { return nil }
        return L10n("Post.Carousel.Counter_index:%lld_count:%lld", locale: locale, index + 1, count)
    }

    /// The dots, only shown when there is more than one photo.
    var indicatorState: PageIndicatorState? {
        PageIndicatorState.make(pageCount: count, currentIndex: index, lastMoveForward: lastMoveForward)
    }
}

private enum ChromeDimensions {
    static let fallbackShadowRadius: CGFloat = 2
    static let indicatorBottomPadding: CGFloat = 16
    static let counterHorizontalPadding: CGFloat = 10
    static let counterVerticalPadding: CGFloat = 4
    static let fallbackBackgroundOpacity: Double = 0.5
    static let visibilityAnimationDuration: Double = 0.2
}

/// The navigation bar of the viewer, laid over the photos: the close button in its leading item and, when there is
/// more than one photo, the counter in its trailing item.
///
/// A real navigation bar, with its items declared like those of the other screens of the SDK, rather than buttons
/// placed by hand: UIKit lays it out like the navigation bar of the screen below, so the close button sits exactly
/// where the back button was, whatever the device, the orientation and the design (with or without the glass effect).
@MainActor
final class FullscreenViewerNavigationController: UINavigationController {
    private let model: FullscreenViewerChromeModel
    private var subscriptions: Set<AnyCancellable> = []

    init(model: FullscreenViewerChromeModel, theme: OctopusTheme, locale: Locale?, close: @escaping () -> Void) {
        self.model = model
        let content = UIHostingController(rootView: FullscreenViewerChromeRoot(theme: theme, locale: locale) {
            FullscreenViewerBarContent(model: model, close: close)
        })
        content.view.backgroundColor = .clear
        super.init(rootViewController: content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance

        model.$isChromeVisible
            .removeDuplicates()
            .sink { [weak self] isVisible in
                guard let self else { return }
                self.view.accessibilityElementsHidden = !isVisible
                UIView.animate(withDuration: ChromeDimensions.visibilityAnimationDuration) {
                    self.view.alpha = isVisible ? 1 : 0
                }
            }
            .store(in: &subscriptions)
    }
}

/// The content of the navigation bar of the viewer: nothing but its items.
private struct FullscreenViewerBarContent: View {
    @ObservedObject var model: FullscreenViewerChromeModel
    let close: () -> Void

    var body: some View {
        Color.clear
            .toolbar(
                leading: FullscreenViewerCloseButton(model: model, close: close),
                trailing: FullscreenViewerCounter(model: model),
                // A text, not a button: no glass around it.
                trailingSharedBackgroundVisibility: .hidden)
    }
}

/// The close button of the viewer.
struct FullscreenViewerCloseButton: View {
    @Environment(\.octopusTheme) private var theme

    let model: FullscreenViewerChromeModel?
    let close: () -> Void

    var body: some View {
        Group {
            if GlassEffect.isAvailable {
                // The bar puts it in glass, like the back button of the screen below.
                CloseButton(action: close)
            } else {
                // Without the glass, the bar draws its items alone: the shadow keeps the cross readable on a light
                // photo, where a background would push it away from the back button of the screen below.
                CloseButton(action: close)
                    .foregroundColor(theme.colors.gray900)
                    .shadow(color: Color.black.opacity(ChromeDimensions.fallbackBackgroundOpacity),
                            radius: ChromeDimensions.fallbackShadowRadius)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.onValueChanged(of: proxy.frame(in: .global), initial: true) { frame in
                    model?.closeButtonFrameInWindow = frame
                }
            }
        )
    }
}

/// The « current / total » counter of the viewer, only shown when there is more than one photo.
struct FullscreenViewerCounter: View {
    @Environment(\.octopusTheme) private var theme

    @ObservedObject var model: FullscreenViewerChromeModel

    var body: some View {
        if let counterText = model.counterText {
            Text(verbatim: counterText)
                .font(theme.fonts.caption1)
                .foregroundColor(.white)
                .padding(.horizontal, ChromeDimensions.counterHorizontalPadding)
                .padding(.vertical, ChromeDimensions.counterVerticalPadding)
                .background(Capsule().fill(Color.black.opacity(ChromeDimensions.fallbackBackgroundOpacity)))
                // Each photo announces its position.
                .accessibilityHidden(true)
        }
    }
}

/// The dots of the viewer, at the bottom, when there is more than one photo.
///
/// It covers the whole screen, safe area included, and keeps the dots above the home indicator from the insets UIKit
/// gives.
struct FullscreenViewerDots: View {
    @Environment(\.layoutDirection) private var layoutDirection

    @ObservedObject var model: FullscreenViewerChromeModel

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                if let state = model.indicatorState {
                    PageIndicatorView(state: state)
                        .padding(.bottom, ChromeDimensions.indicatorBottomPadding)
                }
            }
            .padding(safeAreaPadding)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .edgesIgnoringSafeArea(.all)
        .opacity(model.isChromeVisible ? 1 : 0)
        .animation(.easeInOut(duration: ChromeDimensions.visibilityAnimationDuration), value: model.isChromeVisible)
        .accessibilityHidden(!model.isChromeVisible)
    }

    private var safeAreaPadding: EdgeInsets {
        let insets = model.safeAreaInsets
        let isRightToLeft = layoutDirection == .rightToLeft
        return EdgeInsets(
            top: insets.top,
            leading: isRightToLeft ? insets.right : insets.left,
            bottom: insets.bottom,
            trailing: isRightToLeft ? insets.left : insets.right)
    }
}

/// The view holding the chrome. It covers the whole viewer but only takes the touches of the close button: the
/// others go to the photos below.
final class FullscreenViewerChromeContainer: UIView {
    weak var model: FullscreenViewerChromeModel?

    /// The tappable area of the close button, in the coordinates of this view. Zero while it is not laid out.
    ///
    /// In a navigation bar, the button is only as large as its icon: the bar extends its tappable area to the minimum
    /// tap side, so does this view.
    var closeButtonFrame: CGRect {
        guard let frame = model?.closeButtonFrameInWindow, frame != .zero else { return .zero }
        let buttonFrame = convert(frame, from: nil)
        let side = Self.minimumTapSide
        return buttonFrame.insetBy(dx: min(0, (buttonFrame.width - side) / 2),
                                   dy: min(0, (buttonFrame.height - side) / 2))
    }

    private static let minimumTapSide: CGFloat = 44

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let model, model.isChromeVisible else { return false }
        return closeButtonFrame.contains(point)
    }
}

/// A view of the chrome with the environment it needs: its hosting controller is not in the SwiftUI hierarchy of the
/// screen that opened the viewer, so it does not inherit its environment.
struct FullscreenViewerChromeRoot<Content: View>: View {
    let theme: OctopusTheme
    let locale: Locale?
    @ViewBuilder let content: Content

    var body: some View {
        content
            .environment(\.octopusTheme, theme)
            .environment(\.colorScheme, .dark)
            .modify {
                if let locale {
                    $0.environment(\.locale, locale)
                } else {
                    $0
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black
        VStack {
            HStack {
                FullscreenViewerCloseButton(model: nil, close: {})
                Spacer()
                FullscreenViewerCounter(model: FullscreenViewerChromeModel(index: 2, count: 8, locale: nil))
            }
            .padding(.horizontal, 16)
            Spacer()
        }
        FullscreenViewerDots(model: FullscreenViewerChromeModel(index: 2, count: 8, locale: nil))
    }
    .environment(\.colorScheme, .dark)
    .mockEnvironmentForPreviews()
}
