//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit
import Testing
import Octopus
@testable import OctopusUI

/// The fullscreen viewer, hosted in a 300 × 600 window. Its photos are 400 × 200: each fits at 0.75 (300 × 150,
/// centred vertically).
@MainActor
struct FullscreenImageViewerControllerTests {
    private static let fit: CGFloat = 0.75

    @Test func opensOnTheRequestedIndex() throws {
        let (window, controller) = makeController(itemCount: 3, index: 2)
        defer { window.isHidden = true }

        #expect(controller.currentIndex == 2)
        #expect(controller.pager.contentSize == CGSize(width: 900, height: 600))
        #expect(controller.pager.contentOffset.x == 600)
        #expect(controller.pager.isPagingEnabled)
        // No gap: each page is exactly one width, side by side.
        #expect(controller.pageViews.map(\.frame) == (0..<3).map {
            CGRect(x: CGFloat($0) * 300, y: 0, width: 300, height: 600)
        })
        #expect(controller.chromeModel.index == 2)
        #expect(controller.chromeModel.count == 3)
    }

    @Test(arguments: [(-1, 0), (7, 2)])
    func clampsTheRequestedIndex(requested: Int, expected: Int) throws {
        let (window, controller) = makeController(itemCount: 3, index: requested)
        defer { window.isHidden = true }

        #expect(controller.currentIndex == expected)
        #expect(controller.pager.contentOffset.x == CGFloat(expected) * 300)
    }

    @Test func survivesAnEmptyRequest() throws {
        let closes = Closes()
        let (window, controller) = makeController(itemCount: 0, index: 3, onClose: { closes.indexes.append($0) })
        defer { window.isHidden = true }

        #expect(controller.currentIndex == 0)
        #expect(controller.pageViews.isEmpty)
        #expect(controller.currentImageFrameInWindow == nil)
        #expect(controller.currentImageForTransition == nil)
        #expect(controller.accessibilityPerformEscape())
        #expect(closes.indexes == [0])
    }

    @Test func isDarkAndKeepsALightStatusBar() throws {
        let (window, controller) = makeController(itemCount: 1, index: 0)
        defer { window.isHidden = true }

        #expect(controller.overrideUserInterfaceStyle == .dark)
        #expect(!controller.prefersStatusBarHidden)
        #expect(controller.preferredStatusBarStyle == .lightContent)
        #expect(controller.modalPresentationCapturesStatusBarAppearance)
        #expect(controller.backdropView.backgroundColor == .black)
        #expect(controller.view.accessibilityViewIsModal)
    }

    @Test func doesNotRotateWhereThePresentingScreenDoesNot() throws {
        let host = LockedHostController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        defer { window.isHidden = true }
        window.rootViewController = host
        window.makeKeyAndVisible()
        let controller = FullscreenImageViewerController(
            info: makeInfo(itemCount: 1, index: 0, withImages: true), theme: OctopusTheme(),
            locale: Locale(identifier: "en"), imageLoaders: makeLoaders().loaders, onClose: { _ in })
        // Not presented yet: nothing to follow, the viewer keeps the default of a controller.
        #expect(controller.supportedInterfaceOrientations != .portrait)
        #expect(controller.shouldAutorotate)

        host.present(controller, animated: false)
        #expect(controller.presentingViewController === host)
        #expect(controller.supportedInterfaceOrientations == .portrait)
        #expect(!controller.shouldAutorotate)
    }

    /// The SDK shown in a sheet: the sheet does not decide the orientations, the screen it covers does. A screen
    /// presented full screen does, while it is shown.
    @Test func orientationsComeFromTheScreenTheSheetsCover() {
        let host = LockedHostController()
        let sheet = FakePresentedController(presentedBy: host, fullScreen: false)
        let sheetOverSheet = FakePresentedController(presentedBy: sheet, fullScreen: false)
        let fullScreen = FakePresentedController(presentedBy: sheet, fullScreen: true)
        let sheetOverFullScreen = FakePresentedController(presentedBy: fullScreen, fullScreen: false)

        #expect(FullscreenImageViewerController.orientationReference(from: host) === host)
        #expect(FullscreenImageViewerController.orientationReference(from: sheet) === host)
        #expect(FullscreenImageViewerController.orientationReference(from: sheetOverSheet) === host)
        #expect(FullscreenImageViewerController.orientationReference(from: fullScreen) === fullScreen)
        #expect(FullscreenImageViewerController.orientationReference(from: sheetOverFullScreen) === fullScreen)
        #expect(FullscreenImageViewerController.orientationReference(from: nil) == nil)
    }

    @Test func chromeShowsCounterAndDotsOnlyAboveOnePhoto() throws {
        let (singleWindow, single) = makeController(itemCount: 1, index: 0)
        defer { singleWindow.isHidden = true }
        #expect(single.chromeModel.counterText == nil)
        #expect(single.chromeModel.indicatorState == nil)

        let (window, controller) = makeController(itemCount: 3, index: 1)
        defer { window.isHidden = true }
        #expect(controller.chromeModel.counterText == "2 / 3")
        let state = try #require(controller.chromeModel.indicatorState)
        #expect(state.dots.count == 3)
        #expect(state.selectedPosition == 1)

        controller.pager.contentOffset.x = 600
        #expect(controller.chromeModel.counterText == "3 / 3")
        #expect(controller.chromeModel.indicatorState?.selectedPosition == 2)
    }

    @Test func indexSwitchesAtHalfWidth() throws {
        let (window, controller) = makeController(itemCount: 3, index: 0)
        defer { window.isHidden = true }

        controller.pager.contentOffset.x = 149
        #expect(controller.currentIndex == 0)

        controller.pager.contentOffset.x = 150
        #expect(controller.currentIndex == 1)
        #expect(controller.chromeModel.index == 1)
        #expect(controller.chromeModel.lastMoveForward)

        controller.pager.contentOffset.x = 140
        #expect(controller.currentIndex == 0)
        #expect(!controller.chromeModel.lastMoveForward)
    }

    @Test func rightToLeftStartsFromTheRightmostPage() throws {
        let (window, controller) = makeController(itemCount: 3, index: 0, semantic: .forceRightToLeft)
        defer { window.isHidden = true }

        #expect(controller.pager.contentOffset.x == 600)
        #expect(controller.pageViews[0].frame.minX == 600)

        controller.pager.contentOffset.x = 300
        #expect(controller.currentIndex == 1)
        #expect(controller.chromeModel.lastMoveForward)
    }

    @Test func zoomedPageBlocksPagingAndDismiss() throws {
        let (window, controller) = makeController(itemCount: 3, index: 1)
        defer { window.isHidden = true }
        let page = controller.pageViews[1].zoomingPage
        #expect(controller.pager.isScrollEnabled)
        #expect(controller.dismissPanRecognizer.isEnabled)
        #expect(controller.chromeModel.isChromeVisible)

        page.zoomScale = Self.fit * 2

        #expect(!controller.pager.isScrollEnabled)
        #expect(!controller.dismissPanRecognizer.isEnabled)
        #expect(!controller.chromeModel.isChromeVisible)
        // The pan moves the photo inside its page, natively.
        #expect(page.isScrollEnabled)

        page.zoomScale = Self.fit

        #expect(controller.pager.isScrollEnabled)
        #expect(controller.dismissPanRecognizer.isEnabled)
        #expect(controller.chromeModel.isChromeVisible)
    }

    @Test func dismissPanTakesOneFinger() throws {
        let (window, controller) = makeController(itemCount: 3, index: 1)
        defer { window.isHidden = true }

        // A pinch belongs to the photo, never to the drag that closes.
        #expect(controller.dismissPanRecognizer.maximumNumberOfTouches == 1)
    }

    @Test func zoomOfAnIncomingPageIsFollowedOnceItIsShown() throws {
        let (window, controller) = makeController(itemCount: 3, index: 0)
        defer { window.isHidden = true }
        let incoming = controller.pageViews[1].zoomingPage

        // Pinched while only partly shown: the photo shown is still at fit.
        incoming.zoomScale = Self.fit * 2
        #expect(controller.pager.isScrollEnabled)
        #expect(controller.dismissPanRecognizer.isEnabled)
        #expect(controller.chromeModel.isChromeVisible)

        // Past half the width, it becomes the photo shown: the pager settles on it and stops there.
        controller.pager.contentOffset.x = 200
        #expect(controller.currentIndex == 1)
        #expect(controller.pager.contentOffset.x == 300)
        #expect(!controller.pager.isScrollEnabled)
        #expect(!controller.dismissPanRecognizer.isEnabled)
        #expect(!controller.chromeModel.isChromeVisible)

        incoming.zoomScale = Self.fit
        #expect(controller.pager.isScrollEnabled)
        #expect(controller.dismissPanRecognizer.isEnabled)
        #expect(controller.chromeModel.isChromeVisible)
    }

    @Test(arguments: [PagerRest.endOfDeceleration, .endOfDragWithoutDeceleration])
    func pagerAtRestBringsTheOtherPhotosBackToFit(rest: PagerRest) throws {
        let (window, controller) = makeController(itemCount: 3, index: 0)
        defer { window.isHidden = true }
        let incoming = controller.pageViews[1].zoomingPage
        // Pinched while only partly shown, then let go: the pager goes back to the first photo.
        incoming.zoomScale = Self.fit * 2

        switch rest {
        case .endOfDeceleration:
            controller.scrollViewDidEndDecelerating(controller.pager)
        case .endOfDragWithoutDeceleration:
            controller.scrollViewDidEndDragging(controller.pager, willDecelerate: false)
        }

        #expect(isClose(incoming.zoomScale, Self.fit))
        #expect(!incoming.isZoomed)
        // A later swipe onto it is not stopped halfway.
        controller.pager.contentOffset.x = 200
        #expect(controller.currentIndex == 1)
        #expect(controller.pager.contentOffset.x == 200)
        #expect(controller.pager.isScrollEnabled)
    }

    @Test func pagerStillMovingKeepsTheZoomOfOtherPhotos() throws {
        let (window, controller) = makeController(itemCount: 3, index: 0)
        defer { window.isHidden = true }
        let incoming = controller.pageViews[1].zoomingPage
        incoming.zoomScale = Self.fit * 2

        controller.scrollViewDidEndDragging(controller.pager, willDecelerate: true)

        #expect(isClose(incoming.zoomScale, Self.fit * 2))
    }

    @Test func pagerAtRestKeepsTheZoomOfThePhotoShown() throws {
        let (window, controller) = makeController(itemCount: 3, index: 1)
        defer { window.isHidden = true }
        let shown = controller.pageViews[1].zoomingPage
        shown.zoomScale = Self.fit * 2

        controller.scrollViewDidEndDecelerating(controller.pager)

        #expect(isClose(shown.zoomScale, Self.fit * 2))
        #expect(!controller.pager.isScrollEnabled)
    }

    @Test func pageWaitsForItsImage() throws {
        let loaders = makeLoaders()
        let (window, controller) = makeController(itemCount: 1, index: 0, withImages: false, loaders: loaders)
        defer { window.isHidden = true }
        let pageView = controller.pageViews[0]
        let page = pageView.zoomingPage

        #expect(page.image == nil)
        #expect(pageView.spinner.isAnimating)
        #expect(!pageView.spinner.isHidden)
        #expect(page.pinchGestureRecognizer?.isEnabled != true)
        #expect(!page.doubleTapRecognizer.isEnabled)
        #expect(controller.currentImageFrameInWindow == nil)

        let image = makeImage(size: CGSize(width: 400, height: 200))
        let loader = try #require(loaders.loaders.loader(for: controller.items[0].url))
        loader.image = CachedImage(ratioImage: image, fullSizeImage: image)
        page.layoutIfNeeded()

        #expect(page.image === image)
        #expect(pageView.spinner.isHidden)
        #expect(page.pinchGestureRecognizer?.isEnabled == true)
        #expect(page.doubleTapRecognizer.isEnabled)
        #expect(isClose(page.maximumZoomScale, Self.fit * 5))
    }

    /// Offline, or a photo gone from the server: the page says so and offers to load it again, under the chrome.
    @Test func photoThatFailsToLoadShowsAnErrorWithRetry() async throws {
        // The file does not exist: its download fails.
        let (window, controller) = makeController(itemCount: 1, index: 0, withImages: false)
        defer { window.isHidden = true }
        let pageView = controller.pageViews[0]
        #expect(pageView.failureView.isHidden)

        try await waitUntil { !pageView.failureView.isHidden }
        #expect(!pageView.spinner.isAnimating)
        #expect(pageView.failureLabel.text == L10n("Error.Unknown.Formal", locale: Locale(identifier: "en")))
        #expect(pageView.retryButton.title(for: .normal) == L10n("Common.Retry", locale: Locale(identifier: "en")))
        #expect(controller.chromeModel.isChromeVisible)

        #expect(pageView.retryButton.actions(forTarget: pageView, forControlEvent: .touchUpInside) == ["retryLoading"])
        // The test host has no application to dispatch a button's action.
        pageView.retryLoading()
        #expect(pageView.failureView.isHidden)
        #expect(pageView.spinner.isAnimating)
        // Still missing: the error comes back.
        try await waitUntil { !pageView.failureView.isHidden }
    }

    @Test func pageStartsFromTheImageOfTheRequest() throws {
        let loaders = makeLoaders()
        let (window, controller) = makeController(itemCount: 1, index: 0, loaders: loaders)
        defer { window.isHidden = true }

        #expect(controller.pageViews[0].zoomingPage.image === controller.items[0].image)
        #expect(controller.pageViews[0].spinner.isHidden)
        // Nothing to load for a photo the request already brings.
        #expect(loaders.created.isEmpty)
    }

    @Test func onlyTheCurrentPageAndItsNeighboursLoad() throws {
        let loaders = makeLoaders()
        let (window, controller) = makeController(itemCount: 5, index: 2, withImages: false, loaders: loaders)
        defer { window.isHidden = true }
        let urls = controller.items.map(\.url)
        #expect(Set(loaders.created) == Set(urls[1...3]))

        controller.pager.contentOffset.x = 900

        #expect(Set(loaders.created) == Set(urls[1...4]))
        #expect(loaders.loaders.loader(for: urls[1]) == nil)
        #expect(loaders.loaders.loader(for: urls[4]) != nil)
    }

    @Test func currentImageFrameFollowsTheShownPhoto() throws {
        let (window, controller) = makeController(itemCount: 2, index: 0)
        defer { window.isHidden = true }

        let frame = try #require(controller.currentImageFrameInWindow)
        #expect(isClose(frame, CGRect(x: 0, y: 225, width: 300, height: 150)))
        #expect(controller.currentImageForTransition === controller.items[0].image)

        controller.dragToDismiss(translation: CGPoint(x: 10, y: 100))
        let draggedFrame = try #require(controller.currentImageFrameInWindow)
        #expect(isClose(draggedFrame, CGRect(x: 10, y: 325, width: 300, height: 150)))
    }

    @Test func dragFadesTheBackdropAndAFarReleaseCloses() throws {
        let closes = Closes()
        let (window, controller) = makeController(itemCount: 3, index: 1, onClose: { closes.indexes.append($0) })
        defer { window.isHidden = true }

        // 120 points is half of the progress distance (40 % of 600).
        controller.dragToDismiss(translation: CGPoint(x: 0, y: 120))

        #expect(isClose(controller.backdropView.alpha, 0.5))
        #expect(isClose(controller.chromeContainer.alpha, 0.5))
        #expect(isClose(controller.pageViews[1].transform.ty, 120))

        controller.releaseDragToDismiss(translation: CGPoint(x: 0, y: 120), velocity: .zero)
        #expect(closes.indexes == [1])
    }

    @Test func aShortReleaseSpringsBack() async throws {
        let closes = Closes()
        let (window, controller) = makeController(itemCount: 3, index: 1, onClose: { closes.indexes.append($0) })
        defer { window.isHidden = true }

        controller.dragToDismiss(translation: CGPoint(x: 0, y: 30))
        controller.releaseDragToDismiss(translation: CGPoint(x: 0, y: 30), velocity: .zero)

        #expect(closes.indexes.isEmpty)
        try await waitUntil { controller.pageViews[1].layer.presentation()?.affineTransform() == .identity }
        #expect(controller.pageViews[1].transform == .identity)
        #expect(controller.backdropView.alpha == 1)
        #expect(controller.chromeContainer.alpha == 1)
    }

    /// A flick stopped by the touch that starts the drag leaves the pager between two photos, with neither its
    /// dragging nor its decelerating flag set, and its pan refused for the vertical drag.
    @Test func dragThatClosesPutsAPagerBetweenPhotosBackOnAPage() async throws {
        let (window, controller) = makeController(itemCount: 3, index: 0)
        defer { window.isHidden = true }
        controller.pager.contentOffset.x = 150
        #expect(!controller.pager.isDragging)
        #expect(!controller.pager.isDecelerating)

        controller.beginDragToDismiss()
        controller.dragToDismiss(translation: CGPoint(x: 0, y: 30))
        controller.releaseDragToDismiss(translation: CGPoint(x: 0, y: 30), velocity: .zero)

        #expect([0, 300].contains(controller.pager.contentOffset.x))
        #expect(controller.pager.contentOffset.x == CGFloat(controller.currentIndex) * 300)
        let pageView = controller.pageViews[controller.currentIndex]
        try await waitUntil { pageView.layer.presentation()?.affineTransform() == .identity }
    }

    @Test func springBackPutsAPagerBetweenPhotosBackOnAPage() throws {
        let (window, controller) = makeController(itemCount: 3, index: 0)
        defer { window.isHidden = true }
        controller.dragToDismiss(translation: CGPoint(x: 0, y: 30))
        controller.pager.contentOffset.x = 150

        controller.releaseDragToDismiss(translation: CGPoint(x: 0, y: 30), velocity: .zero)

        #expect([0, 300].contains(controller.pager.contentOffset.x))
        #expect(controller.pager.contentOffset.x == CGFloat(controller.currentIndex) * 300)
    }

    @Test func escapeClosesWithTheCurrentIndex() throws {
        let closes = Closes()
        let (window, controller) = makeController(itemCount: 3, index: 0, onClose: { closes.indexes.append($0) })
        defer { window.isHidden = true }

        controller.pager.contentOffset.x = 600

        #expect(controller.accessibilityPerformEscape())
        #expect(closes.indexes == [2])
    }

    @Test func voiceOverScrollChangesThePage() throws {
        let (window, controller) = makeController(itemCount: 3, index: 0)
        defer { window.isHidden = true }

        #expect(controller.pager.accessibilityScroll(.left))
        #expect(controller.currentIndex == 1)
        #expect(controller.pager.contentOffset.x == 300)
        #expect(controller.pager.accessibilityScroll(.right))
        #expect(controller.currentIndex == 0)
        // Already on the first photo.
        #expect(!controller.pager.accessibilityScroll(.right))
    }

    @Test func voiceOverAdjustChangesThePage() throws {
        let (window, controller) = makeController(itemCount: 3, index: 0)
        defer { window.isHidden = true }
        #expect(controller.pageViews.allSatisfy { $0.zoomingPage.accessibilityTraits.contains(.adjustable) })

        controller.pageViews[0].zoomingPage.accessibilityIncrement()
        #expect(controller.currentIndex == 1)
        #expect(controller.pager.contentOffset.x == 300)
        controller.pageViews[1].zoomingPage.accessibilityIncrement()
        #expect(controller.currentIndex == 2)
        // Already on the last photo.
        controller.pageViews[2].zoomingPage.accessibilityIncrement()
        #expect(controller.currentIndex == 2)
        controller.pageViews[2].zoomingPage.accessibilityDecrement()
        #expect(controller.currentIndex == 1)
        // The traits of a photo are kept.
        #expect(controller.pageViews[1].zoomingPage.accessibilityTraits.contains(.image))
    }

    @Test func voiceOverAdjustFollowsTheReadingOrderRightToLeft() throws {
        let (window, controller) = makeController(itemCount: 3, index: 0, semantic: .forceRightToLeft)
        defer { window.isHidden = true }

        controller.pageViews[0].zoomingPage.accessibilityIncrement()

        #expect(controller.currentIndex == 1)
        #expect(controller.pager.contentOffset.x == 300)
    }

    @Test func singlePhotoIsNotAdjustable() throws {
        let (window, controller) = makeController(itemCount: 1, index: 0)
        defer { window.isHidden = true }
        let page = controller.pageViews[0].zoomingPage

        #expect(!page.accessibilityTraits.contains(.adjustable))
        page.accessibilityIncrement()
        #expect(controller.currentIndex == 0)
    }

    @Test func pagesAreLabelledWithTheirPositionAboveOnePhoto() throws {
        let (window, controller) = makeController(itemCount: 3, index: 0)
        defer { window.isHidden = true }
        #expect(controller.pageViews[1].zoomingPage.accessibilityLabel == "Image 2 of 3")
        #expect(controller.pageViews[1].zoomingPage.locale == Locale(identifier: "en"))

        let (singleWindow, single) = makeController(itemCount: 1, index: 0)
        defer { singleWindow.isHidden = true }
        #expect(single.pageViews[0].zoomingPage.accessibilityLabel == nil)
    }

    /// A photo shown alone has no position to read: it takes the label the request gives, such as the avatar's.
    @Test func aPhotoShownAloneTakesTheLabelOfTheRequest() {
        let item = ZoomableImageInfo.Item(url: URL(fileURLWithPath: "/nonexistent/avatar.jpg"),
                                          image: makeImage(size: CGSize(width: 200, height: 200)),
                                          transitionImage: nil)
        let controller = FullscreenImageViewerController(
            info: ZoomableImageInfo(items: [item], index: 0, accessibilityLabelKey: "Accessibility.Profile.Picture",
                                    sourceFrame: nil),
            theme: OctopusTheme(), locale: Locale(identifier: "en"), imageLoaders: makeLoaders().loaders,
            onClose: { _ in })
        controller.loadViewIfNeeded()

        #expect(controller.pageViews[0].zoomingPage.accessibilityLabel == "Profile picture")
    }

    @Test func chromeLetsTouchesThroughOutsideTheCloseButton() async throws {
        let closes = Closes()
        let (window, controller) = makeController(itemCount: 3, index: 0, onClose: { closes.indexes.append($0) })
        defer { window.isHidden = true }
        let chrome = controller.chromeContainer
        try await waitUntil { controller.chromeContainer.closeButtonFrame.width > 0 }
        let closeFrame = controller.chromeContainer.closeButtonFrame

        #expect(closeFrame.width >= 44)
        #expect(closeFrame.height >= 44)
        // Top leading.
        #expect(closeFrame.midX < 150)
        #expect(closeFrame.midY < 300)
        #expect(chrome.hitTest(CGPoint(x: closeFrame.midX, y: closeFrame.midY), with: nil) != nil)
        #expect(chrome.hitTest(CGPoint(x: 150, y: 300), with: nil) == nil)
        #expect(controller.view.hitTest(CGPoint(x: 150, y: 300), with: nil)?.isDescendant(of: controller.pager) == true)
    }

    @Test func closeButtonStaysBelowTheTopSafeArea() async throws {
        let (window, controller) = makeController(itemCount: 1, index: 0)
        defer { window.isHidden = true }
        // Stands for the status bar and the sensor housing, which the test window does not have.
        controller.additionalSafeAreaInsets = UIEdgeInsets(top: 60, left: 0, bottom: 34, right: 0)
        controller.view.layoutIfNeeded()

        try await waitUntil { controller.chromeContainer.closeButtonFrame.minY >= 60 }
    }

    @Test func isReleasedOnceClosed() throws {
        weak var released: FullscreenImageViewerController?
        autoreleasepool {
            let controller = FullscreenImageViewerController(
                info: makeInfo(itemCount: 3, index: 1, withImages: true),
                theme: OctopusTheme(), locale: nil, imageLoaders: makeLoaders().loaders, onClose: { _ in })
            controller.loadViewIfNeeded()
            controller.view.frame = CGRect(x: 0, y: 0, width: 300, height: 600)
            controller.view.layoutIfNeeded()
            controller.pageViews[1].zoomingPage.zoomScale = Self.fit * 2
            released = controller
        }
        #expect(released == nil)
    }

    // MARK: Helpers

    private func makeController(
        itemCount: Int, index: Int, withImages: Bool = true, loaders: TrackedLoaders? = nil,
        semantic: UISemanticContentAttribute = .unspecified,
        onClose: @escaping (Int) -> Void = { _ in }) -> (UIWindow, FullscreenImageViewerController) {
        let controller = FullscreenImageViewerController(
            info: makeInfo(itemCount: itemCount, index: index, withImages: withImages),
            theme: OctopusTheme(),
            locale: Locale(identifier: "en"),
            imageLoaders: (loaders ?? makeLoaders()).loaders,
            onClose: onClose)
        // The test host runs without scenes, so the window is attached to the screen directly.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        controller.loadViewIfNeeded()
        controller.view.semanticContentAttribute = semantic
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        return (window, controller)
    }

    private func makeInfo(itemCount: Int, index: Int, withImages: Bool) -> ZoomableImageInfo {
        let items = (0..<itemCount).map { offset in
            // Files that do not exist: a page without an image waits for it, then fails, without any network call.
            ZoomableImageInfo.Item(
                url: URL(fileURLWithPath: "/nonexistent/viewer-\(UUID().uuidString)-\(offset).jpg"),
                image: withImages ? makeImage(size: CGSize(width: 400, height: 200)) : nil,
                transitionImage: nil)
        }
        return ZoomableImageInfo(items: items, index: index, sourceFrame: nil)
    }

    private func makeLoaders() -> TrackedLoaders {
        let tracked = TrackedLoaders()
        // Weak: the tracker holds the loaders, which hold this closure.
        tracked.loaders = CarouselImageLoaders(makeLoader: { [weak tracked] url in
            tracked?.created.append(url)
            return AsyncCachedImageLoader(url, cache: .content, croppingRatio: nil)
        })
        return tracked
    }
}

enum PagerRest {
    case endOfDeceleration
    case endOfDragWithoutDeceleration
}

@MainActor
private final class TrackedLoaders {
    var created: [URL] = []
    var loaders: CarouselImageLoaders!
}

@MainActor
private final class Closes {
    var indexes: [Int] = []
}

/// A screen locked to portrait, as a host or a game forcing an orientation makes it.
private final class LockedHostController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var shouldAutorotate: Bool { false }
}

/// A controller presented in a sheet or full screen, without the presentation running: the test host has no scene for
/// one.
private final class FakePresentedController: UIViewController {
    private let presenter: UIViewController
    private let isFullScreen: Bool
    private lazy var fakePresentation = FakePresentationController(
        presentedViewController: self, presenting: presenter, isFullScreen: isFullScreen)

    init(presentedBy presenter: UIViewController, fullScreen: Bool) {
        self.presenter = presenter
        isFullScreen = fullScreen
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var presentingViewController: UIViewController? { presenter }
    override var presentationController: UIPresentationController? { fakePresentation }
}

private final class FakePresentationController: UIPresentationController {
    private let isFullScreen: Bool

    init(presentedViewController: UIViewController, presenting: UIViewController?, isFullScreen: Bool) {
        self.isFullScreen = isFullScreen
        super.init(presentedViewController: presentedViewController, presenting: presenting)
    }

    override var shouldPresentInFullscreen: Bool { isFullScreen }
}

@MainActor
private func makeImage(size: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

private func isClose(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
    abs(lhs - rhs) < 0.001
}

private func isClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
    isClose(lhs.minX, rhs.minX) && isClose(lhs.minY, rhs.minY)
        && isClose(lhs.width, rhs.width) && isClose(lhs.height, rhs.height)
}
