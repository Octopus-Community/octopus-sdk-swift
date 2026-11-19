//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import SwiftUI
import UIKit
import OctopusCore
import Octopus

/// The fullscreen photo viewer: every photo of a content, paged horizontally and each zoomable, under a chrome (close
/// button, counter and dots), on a black backdrop. A vertical drag closes it.
///
/// While the shown photo is zoomed, the drag moves the photo inside its page: paging and the drag that closes are
/// disabled, and the chrome fades out. Back at fit, everything comes back.
final class FullscreenImageViewerController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    /// The photos, possibly empty when the request was: the viewer then shows nothing and only closes.
    let items: [ZoomableImageInfo.Item]
    /// The key of the VoiceOver label of a photo shown alone.
    private let accessibilityLabelKey: String?
    /// The index of the photo shown.
    private(set) var currentIndex: Int
    /// The frame, in window coordinates, of the photo shown, as it is on screen (dragged, zoomed). `nil` while the
    /// photo is not loaded or the viewer not in a window.
    var currentImageFrameInWindow: CGRect? {
        guard let pageView = currentPageView, pageView.zoomingPage.image != nil, pageView.window != nil else {
            return nil
        }
        let imageView = pageView.zoomingPage.imageView
        return imageView.convert(imageView.bounds, to: nil)
    }
    /// The image of the photo shown, for the transition that closes the viewer.
    var currentImageForTransition: UIImage? {
        guard items.indices.contains(currentIndex) else { return nil }
        // The pages only exist once the view is loaded.
        return currentPageView?.zoomingPage.image ?? items[currentIndex].image ?? items[currentIndex].transitionImage
    }

    let chromeModel: FullscreenViewerChromeModel
    let backdropView = UIView()
    let pager = FullscreenViewerPager()
    /// One page per photo, in the order of `items`.
    private(set) var pageViews: [FullscreenViewerPageView] = []
    let chromeContainer = FullscreenViewerChromeContainer()
    /// The vertical drag that closes the viewer.
    private(set) lazy var dismissPanRecognizer: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        // One finger: a pinch belongs to the photo.
        recognizer.maximumNumberOfTouches = 1
        recognizer.delegate = self
        return recognizer
    }()

    private let theme: OctopusTheme
    private let locale: Locale?
    private let textTone: TextTone
    private let onClose: (_ index: Int) -> Void
    private let imageLoaders: CarouselImageLoaders
    /// The observations of the loaders of the pages that load their image, by index.
    private var loaderSubscriptions: [Int: AnyCancellable] = [:]

    /// The size and direction the pages were laid out for.
    private var laidOutSize: CGSize = .zero
    private var isRightToLeft = false
    /// True while the offset is set by code, so that it is not taken for a page change.
    private var isSettingOffset = false
    /// Whether the photo shown is zoomed.
    private var isZoomed = false

    private enum Animation {
        static let springBackDuration: TimeInterval = 0.35
        static let springBackDamping: CGFloat = 0.85
    }

    /// - Parameters:
    ///   - info: the photos and the one to open on. An index outside of the photos is brought back to them.
    ///   - theme: the theme of the chrome.
    ///   - locale: the language the SDK overrides the device's with, if any, for the VoiceOver texts.
    ///   - textTone: the member's tone, which picks the version of the texts that address the member.
    ///   - imageLoaders: where the photos that the request does not bring are loaded. By default, the content cache.
    ///   - onClose: called with the index of the photo shown when the reader closes the viewer. The caller dismisses
    ///     it.
    init(info: ZoomableImageInfo, theme: OctopusTheme, locale: Locale?, textTone: TextTone = .formal,
         imageLoaders: CarouselImageLoaders? = nil,
         onClose: @escaping (_ index: Int) -> Void) {
        items = info.items
        accessibilityLabelKey = info.accessibilityLabelKey
        // The request does not guarantee a valid index, nor any photo.
        currentIndex = info.items.isEmpty ? 0 : min(max(info.index, 0), info.items.count - 1)
        chromeModel = FullscreenViewerChromeModel(index: currentIndex, count: info.items.count, locale: locale)
        self.theme = theme
        self.locale = locale
        self.textTone = textTone
        self.onClose = onClose
        self.imageLoaders = imageLoaders ?? CarouselImageLoaders(makeLoader: {
            // The viewer shows the whole photo: no cropping.
            AsyncCachedImageLoader($0, cache: .content, croppingRatio: nil)
        })
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalPresentationCapturesStatusBarAppearance = true
        overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // The status bar stays, so the time is still there, and the close button sits below it rather than alone in the
    // top corner. Light, to read on the black backdrop.
    override var prefersStatusBarHidden: Bool { false }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }

    // The viewer fills the window, so UIKit asks it, not the screen below, which orientations are allowed. It does
    // not rotate where the screen below does not: a host locked to portrait, or a Unity game forcing one orientation
    // on the community, would otherwise see the screen laid out in another orientation while the viewer is open.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        Self.orientationReference(from: presentingViewController)?.supportedInterfaceOrientations
            ?? super.supportedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        Self.orientationReference(from: presentingViewController)?.shouldAutorotate ?? super.shouldAutorotate
    }

    /// The controller UIKit asks for the orientations of the screen below the viewer: the nearest one, from
    /// `presenter` up, that is presented full screen, or the window's root. A sheet is not asked: the screen it
    /// covers decides, so the SDK shown in a sheet over a host locked to portrait stays in portrait.
    static func orientationReference(from presenter: UIViewController?) -> UIViewController? {
        var controller = presenter
        while let current = controller, let below = current.presentingViewController,
              current.presentationController?.shouldPresentInFullscreen == false {
            controller = below
        }
        return controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The backdrop fades during the drag that closes: the screen below shows through.
        view.backgroundColor = .clear
        view.accessibilityViewIsModal = true

        backdropView.backgroundColor = .black
        backdropView.frame = view.bounds
        backdropView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backdropView)

        setUpPager()
        setUpPages()
        setUpChrome()

        view.addGestureRecognizer(dismissPanRecognizer)
        // The close button first, then the photo.
        view.accessibilityElements = [chromeContainer, pager]

        updateShownPages()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let isRightToLeft = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        guard view.bounds.size != laidOutSize || isRightToLeft != self.isRightToLeft else { return }
        layoutPages(size: view.bounds.size, isRightToLeft: isRightToLeft)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        chromeModel.safeAreaInsets = view.safeAreaInsets
    }

    override func accessibilityPerformEscape() -> Bool {
        close()
        return true
    }

    // MARK: Set up

    private func setUpPager() {
        pager.isPagingEnabled = true
        pager.isDirectionalLockEnabled = true
        pager.alwaysBounceVertical = false
        pager.showsHorizontalScrollIndicator = false
        pager.showsVerticalScrollIndicator = false
        pager.scrollsToTop = false
        pager.contentInsetAdjustmentBehavior = .never
        // The offsets are computed from the left edge, whatever the layout direction.
        pager.semanticContentAttribute = .forceLeftToRight
        pager.backgroundColor = .clear
        pager.delegate = self
        pager.onAccessibilityScroll = { [weak self] direction in
            self?.scrollForAccessibility(direction) ?? false
        }
        view.addSubview(pager)
    }

    private func setUpPages() {
        let count = items.count
        pageViews = items.enumerated().map { index, item in
            let pageView = FullscreenViewerPageView()
            let page = pageView.zoomingPage
            page.locale = locale
            if count > 1 {
                page.accessibilityLabel = L10n(
                    "Accessibility.Carousel.Position_index:%lld_count:%lld", locale: locale, index + 1, count)
                // A swipe up or down on the photo changes the photo shown, besides the three-finger scroll.
                page.onAccessibilityAdjust = { [weak self] forward in
                    self?.adjustForAccessibility(forward: forward) ?? false
                }
            } else if let accessibilityLabelKey {
                page.accessibilityLabel = L10n(accessibilityLabelKey, locale: locale)
            }
            // Weak: the controller owns the pages.
            page.onZoomChange = { [weak self] isZoomed in
                self?.pageZoomDidChange(isZoomed, at: index)
            }
            pageView.setImage(item.image)
            pager.addSubview(pageView)
            return pageView
        }
    }

    private func setUpChrome() {
        chromeContainer.model = chromeModel
        chromeContainer.frame = view.bounds
        chromeContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(chromeContainer)

        let dotsController = UIHostingController(rootView: FullscreenViewerChromeRoot(theme: theme, locale: locale) {
            FullscreenViewerDots(model: chromeModel)
        })
        dotsController.view.backgroundColor = .clear
        embedInChrome(dotsController)

        let navigationController = FullscreenViewerNavigationController(
            model: chromeModel, theme: theme, locale: locale, close: { [weak self] in self?.close() })
        embedInChrome(navigationController)
    }

    private func embedInChrome(_ controller: UIViewController) {
        addChild(controller)
        controller.view.frame = chromeContainer.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        chromeContainer.addSubview(controller.view)
        controller.didMove(toParent: self)
    }

    // MARK: Paging

    private var currentPageView: FullscreenViewerPageView? {
        pageViews.indices.contains(currentIndex) ? pageViews[currentIndex] : nil
    }

    /// Lays the pages side by side, one per width and without gap, and scrolls to the photo shown.
    private func layoutPages(size: CGSize, isRightToLeft: Bool) {
        laidOutSize = size
        self.isRightToLeft = isRightToLeft
        isSettingOffset = true
        defer { isSettingOffset = false }

        pager.frame = CGRect(origin: .zero, size: size)
        pager.contentSize = CGSize(width: size.width * CGFloat(items.count), height: size.height)
        for (index, pageView) in pageViews.enumerated() {
            // Bounds and centre rather than frame: the page shown may be translated by the drag that closes.
            pageView.bounds = CGRect(origin: .zero, size: size)
            pageView.center = CGPoint(x: (CGFloat(position(of: index)) + 0.5) * size.width, y: size.height / 2)
        }
        pager.contentOffset = CGPoint(x: CGFloat(position(of: currentIndex)) * size.width, y: 0)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // While the bounds differ from the laid-out size, the offset moves because UIKit clamps it to the old content
        // size, not because of the reader: the layout puts it back on the photo shown.
        guard scrollView === pager, !isSettingOffset, pager.bounds.size == laidOutSize, !items.isEmpty else { return }
        let slot = PagingRules.index(offsetX: pager.contentOffset.x, pageWidth: pager.bounds.width, count: items.count)
        let index = position(of: slot)
        guard index != currentIndex else { return }
        show(index)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView === pager, !decelerate else { return }
        resetOtherPagesZoom()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === pager else { return }
        resetOtherPagesZoom()
    }

    /// Brings the photos other than the one shown back to fit once the pager is at rest.
    ///
    /// A photo pinched while it was only partly shown keeps its zoom: swiping onto it later would make it the zoomed
    /// photo shown halfway through the swipe, which stops the pager and cancels the swipe.
    private func resetOtherPagesZoom() {
        for (index, pageView) in pageViews.enumerated() where index != currentIndex && pageView.zoomingPage.isZoomed {
            pageView.zoomingPage.resetZoom(animated: false)
        }
    }

    private func show(_ index: Int) {
        // A photo zoomed by VoiceOver is left at fit, so that the zoomed state follows the photo shown.
        if isZoomed {
            currentPageView?.zoomingPage.resetZoom(animated: false)
        }
        let moveForward = index > currentIndex
        currentIndex = index
        if chromeModel.lastMoveForward != moveForward {
            chromeModel.lastMoveForward = moveForward
        }
        chromeModel.index = index
        updateShownPages()
        // The reader may have pinched the incoming photo while it was only partly shown, before it became the
        // current one: its zoom was not followed until now.
        applyZoomed(currentPageView?.zoomingPage.isZoomed ?? false)
    }

    /// Loads the photos of the page shown and of its neighbours, releases the others, and only exposes the page shown
    /// to VoiceOver.
    private func updateShownPages() {
        let nearby = Set(items.indices.filter { abs($0 - currentIndex) <= 1 })
        let toLoad = nearby.sorted().filter { items[$0].image == nil }
        imageLoaders.keep(toLoad.map { items[$0].url })
        for (index, pageView) in pageViews.enumerated() {
            pageView.accessibilityElementsHidden = index != currentIndex
            if toLoad.contains(index) {
                guard loaderSubscriptions[index] == nil,
                      let loader = imageLoaders.loader(for: items[index].url) else { continue }
                loaderSubscriptions[index] = loader.$image.combineLatest(loader.$didFail)
                    .sink { [weak self, weak loader] cachedImage, didFail in
                        self?.showLoad(of: index, image: cachedImage?.fullSizeImage, didFail: didFail, loader: loader)
                    }
            } else if !nearby.contains(index) {
                // A full size photo takes a lot of memory: keep only the ones the request brings.
                loaderSubscriptions[index] = nil
                pageView.setImage(items[index].image)
            }
        }
    }

    /// Shows the photo of page `index`, the spinner while it loads, or the error with Retry once its download failed.
    private func showLoad(of index: Int, image: UIImage?, didFail: Bool, loader: AsyncCachedImageLoader?) {
        let pageView = pageViews[index]
        guard image == nil, didFail else {
            pageView.setImage(image)
            return
        }
        pageView.showFailure(
            message: L10n(textTone.stringKey(formal: "Error.Unknown.Formal", informal: "Error.Unknown.Informal"),
                          locale: locale),
            retryTitle: L10n("Common.Retry", locale: locale),
            retry: { [weak loader] in loader?.retry() })
    }

    /// Where page `index` sits in the row, from the left. The mapping is its own inverse.
    private func position(of index: Int) -> Int {
        isRightToLeft ? items.count - 1 - index : index
    }

    // MARK: Zoom

    private func pageZoomDidChange(_ isZoomed: Bool, at index: Int) {
        // The zoom of another page is followed once that page becomes the current one (`show`).
        guard index == currentIndex else { return }
        applyZoomed(isZoomed)
    }

    private func applyZoomed(_ isZoomed: Bool) {
        guard isZoomed != self.isZoomed else { return }
        self.isZoomed = isZoomed
        if isZoomed {
            // The pager may still be moving: settle it on the zoomed photo before it stops scrolling, rather than
            // leaving it between two photos.
            alignPagerOnCurrentPage()
        }
        pager.isScrollEnabled = !isZoomed
        dismissPanRecognizer.isEnabled = !isZoomed
        chromeModel.isChromeVisible = !isZoomed
    }

    private func alignPagerOnCurrentPage() {
        guard laidOutSize.width > 0 else { return }
        let offset = CGPoint(x: CGFloat(position(of: currentIndex)) * laidOutSize.width, y: 0)
        guard pager.contentOffset != offset else { return }
        isSettingOffset = true
        defer { isSettingOffset = false }
        pager.setContentOffset(offset, animated: false)
    }

    // MARK: Drag to close

    /// Starts the drag that closes on the photo shown, put back on its page.
    ///
    /// A touch stops the pager where it was decelerating, possibly between two photos, and the drag that follows is
    /// vertical, so the pager's own pan never runs to snap it back: the pager is aligned here, whatever its flags say.
    func beginDragToDismiss() {
        alignPagerOnCurrentPage()
    }

    /// Follows the finger: the photo shown moves with it, and the backdrop and the chrome fade as it goes away.
    func dragToDismiss(translation: CGPoint) {
        let progress = DismissRules.progress(translationY: translation.y, height: view.bounds.height)
        currentPageView?.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
        backdropView.alpha = 1 - progress
        chromeContainer.alpha = 1 - progress
    }

    /// Closes the viewer when the drag went far or fast enough, from where the photo is. Otherwise, puts it back.
    func releaseDragToDismiss(translation: CGPoint, velocity: CGPoint) {
        if DismissRules.shouldDismiss(translationY: translation.y, velocityY: velocity.y, height: view.bounds.height) {
            close()
        } else {
            springBack()
        }
    }

    private func springBack() {
        // The drag may have started with the pager between two photos: never leave it there.
        alignPagerOnCurrentPage()
        UIView.animate(
            withDuration: Animation.springBackDuration, delay: 0,
            usingSpringWithDamping: Animation.springBackDamping, initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.currentPageView?.transform = .identity
                self.backdropView.alpha = 1
                self.chromeContainer.alpha = 1
            }
    }

    @objc private func handleDismissPan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: view)
        switch recognizer.state {
        case .began:
            beginDragToDismiss()
            dragToDismiss(translation: translation)
        case .changed:
            dragToDismiss(translation: translation)
        case .ended:
            releaseDragToDismiss(translation: translation, velocity: recognizer.velocity(in: view))
        case .cancelled, .failed:
            springBack()
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissPanRecognizer else { return true }
        return DismissRules.dragShouldBegin(
            velocity: dismissPanRecognizer.velocity(in: view),
            isZoomed: isZoomed,
            isPaging: pager.isDragging || pager.isDecelerating)
    }

    // MARK: VoiceOver

    /// Shows the next or the previous photo for a three-finger scroll of VoiceOver.
    ///
    /// Whether the scroll of a photo at fit reaches the pager, rather than being taken by the photo's own scroll view,
    /// is to be checked on a device.
    private func scrollForAccessibility(_ direction: UIAccessibilityScrollDirection) -> Bool {
        let step: Int
        switch direction {
        case .left: step = 1
        case .right: step = -1
        default: return false
        }
        return showForAccessibility(atPosition: position(of: currentIndex) + step)
    }

    /// Shows the next photo, or the previous one, for the VoiceOver swipe up or down on the photo shown.
    private func adjustForAccessibility(forward: Bool) -> Bool {
        showForAccessibility(atPosition: position(of: currentIndex + (forward ? 1 : -1)))
    }

    /// Shows the photo at `targetPosition` in the row, and moves the VoiceOver focus to it. Returns false when there
    /// is no photo there.
    private func showForAccessibility(atPosition targetPosition: Int) -> Bool {
        guard items.indices.contains(targetPosition), pager.bounds.width > 0 else { return false }
        if isZoomed {
            currentPageView?.zoomingPage.resetZoom(animated: false)
        }
        pager.setContentOffset(CGPoint(x: CGFloat(targetPosition) * pager.bounds.width, y: 0), animated: false)
        UIAccessibility.post(notification: .layoutChanged, argument: currentPageView?.zoomingPage)
        return true
    }

    // MARK: Close

    private func close() {
        onClose(currentIndex)
    }
}
