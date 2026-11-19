//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

/// Which page of a paging scroll view is the current one.
enum CarouselIndex {
    /// The index of the current page for a horizontal content offset.
    ///
    /// The index switches as soon as the next page covers half of the width, not when it is fully shown.
    /// - Parameters:
    ///   - contentOffsetX: the horizontal content offset of the scroll view.
    ///   - pageWidth: the width of a page.
    ///   - pageCount: the number of pages.
    /// - Returns: the index of the page, clamped to `0...pageCount - 1`.
    static func index(contentOffsetX: CGFloat, pageWidth: CGFloat, pageCount: Int) -> Int {
        guard pageWidth > 0, pageCount > 0 else { return 0 }
        let position = ((contentOffsetX + pageWidth / 2) / pageWidth).rounded(.down)
        guard position.isFinite else { return 0 }
        return min(max(Int(position), 0), pageCount - 1)
    }
}

/// A horizontal paging scroll view, one page per width.
///
/// It is a `UIScrollView` because a paging scroll view is not available in SwiftUI before iOS 17. It only scrolls
/// horizontally, so UIKit hands the vertical drags to the enclosing feed.
///
/// The pages are laid out by one hosting controller, in a row of pages as wide as the view. In a right-to-left
/// layout, the first page is the rightmost one. The hosting controller is a child of the controller of the scroll
/// view: a hosting controller outside of the hierarchy of view controllers is not guaranteed to draw the updates of
/// its root view, and on some devices the pages kept what they showed when the carousel appeared.
///
/// The pages are built with the scroll view, not when the hosting controller draws them: what a page shows is read
/// in the same update as the data it comes from, and a change of that data is a change of the pages.
struct PagingScrollView<Page: View>: UIViewControllerRepresentable {
    let pages: [Page]
    @Binding var currentIndex: Int
    /// Whether the last page change went toward the end.
    @Binding var lastMoveForward: Bool

    var pageCount: Int { pages.count }

    init(pageCount: Int, currentIndex: Binding<Int>, lastMoveForward: Binding<Bool>,
         @ViewBuilder page: (Int) -> Page) {
        self.pages = (0..<pageCount).map(page)
        self._currentIndex = currentIndex
        self._lastMoveForward = lastMoveForward
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PagingViewController<Page> {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.isRightToLeft = context.environment.layoutDirection == .rightToLeft
        coordinator.colorScheme = context.environment.colorScheme
        coordinator.shownIndex = clamped(currentIndex)

        let controller = PagingViewController(rootView: coordinator.rootView(pageSize: .zero))
        controller.loadViewIfNeeded()
        let scrollView = controller.scrollView
        scrollView.isPagingEnabled = true
        scrollView.isDirectionalLockEnabled = true
        scrollView.alwaysBounceVertical = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.scrollsToTop = false
        scrollView.contentInsetAdjustmentBehavior = .never
        // The offsets are computed from the left edge, whatever the layout direction.
        scrollView.semanticContentAttribute = .forceLeftToRight
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true
        scrollView.delegate = coordinator
        coordinator.hostingController = controller.hostingController

        scrollView.onLayout = { [weak coordinator] scrollView in
            coordinator?.layout(scrollView, force: false)
        }
        return controller
    }

    func updateUIViewController(_ controller: PagingViewController<Page>, context: Context) {
        let scrollView = controller.scrollView
        let coordinator = context.coordinator
        let pageCountChanged = coordinator.parent.pageCount != pageCount
        let isRightToLeft = context.environment.layoutDirection == .rightToLeft
        let directionChanged = coordinator.isRightToLeft != isRightToLeft
        coordinator.parent = self
        coordinator.isRightToLeft = isRightToLeft
        coordinator.colorScheme = context.environment.colorScheme

        let requestedIndex = clamped(currentIndex)
        let isUserScrolling = scrollView.isDragging || scrollView.isDecelerating
        let indexChanged = requestedIndex != coordinator.shownIndex && !isUserScrolling
        if indexChanged {
            // Set from outside (a recycled cell restoring its position, VoiceOver): go there without animation.
            coordinator.shownIndex = requestedIndex
        }
        if pageCountChanged || directionChanged || indexChanged {
            coordinator.layout(scrollView, force: true)
        } else {
            // The pages may depend on data that changed (the current index, the loaded images…).
            coordinator.updatePages()
        }
    }

    private func clamped(_ index: Int) -> Int {
        min(max(index, 0), max(pageCount - 1, 0))
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: PagingScrollView
        var hostingController: UIHostingController<PagesRow<Page>>?
        var isRightToLeft = false
        var colorScheme: ColorScheme = .light
        /// The index of the page shown, as last reported to (or received from) SwiftUI.
        var shownIndex = 0

        private var laidOutSize: CGSize = .zero
        /// True while the offset is set by code, so that it is not reported as a move of the user.
        private var isSettingOffset = false

        init(parent: PagingScrollView) {
            self.parent = parent
        }

        func rootView(pageSize: CGSize) -> PagesRow<Page> {
            PagesRow(
                pageCount: parent.pageCount,
                pageSize: pageSize,
                isRightToLeft: isRightToLeft,
                colorScheme: colorScheme,
                pages: parent.pages)
        }

        /// Gives the hosting controller the latest pages.
        func updatePages() {
            hostingController?.rootView = rootView(pageSize: laidOutSize)
        }

        /// Lays the pages out for the size of the scroll view and scrolls to the shown page.
        func layout(_ scrollView: UIScrollView, force: Bool) {
            let size = scrollView.bounds.size
            guard let hostingController else { return }
            if !force && size == laidOutSize { return }
            laidOutSize = size

            isSettingOffset = true
            defer { isSettingOffset = false }

            let contentSize = CGSize(width: size.width * CGFloat(parent.pageCount), height: size.height)
            updatePages()
            hostingController.view.frame = CGRect(origin: .zero, size: contentSize)
            scrollView.contentSize = contentSize
            scrollView.setContentOffset(
                CGPoint(x: CGFloat(position(of: shownIndex)) * size.width, y: 0),
                animated: false)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // While the bounds differ from the laid-out size, the offset moves because UIKit clamps it to the old
            // content size (a wider frame), not because of the user: `layout` puts it back on the shown page.
            guard !isSettingOffset, scrollView.bounds.size == laidOutSize else { return }
            let pageCount = parent.pageCount
            let slot = CarouselIndex.index(
                contentOffsetX: scrollView.contentOffset.x,
                pageWidth: scrollView.bounds.width,
                pageCount: pageCount)
            let index = position(of: slot)
            guard index != shownIndex else { return }
            let moveForward = index > shownIndex
            shownIndex = index
            if parent.lastMoveForward != moveForward {
                parent.lastMoveForward = moveForward
            }
            if parent.currentIndex != index {
                parent.currentIndex = index
            }
        }

        /// Where page `index` sits in the row, from the left. The mapping is its own inverse.
        private func position(of index: Int) -> Int {
            isRightToLeft ? parent.pageCount - 1 - index : index
        }
    }
}

/// The controller of `PagingScrollView`: its view is the scroll view, and the hosting controller of the pages is its
/// child.
final class PagingViewController<Page: View>: UIViewController {
    let scrollView = PagingUIScrollView()
    let hostingController: UIHostingController<PagesRow<Page>>

    init(rootView: PagesRow<Page>) {
        hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = scrollView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hostingController.view.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }
        addChild(hostingController)
        scrollView.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}

/// The scroll view of `PagingScrollView`, which reports its layouts so the pages follow its size.
final class PagingUIScrollView: UIScrollView {
    var onLayout: ((UIScrollView) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(self)
    }
}

/// The row of pages hosted in the scroll view.
struct PagesRow<Page: View>: View {
    let pageCount: Int
    let pageSize: CGSize
    let isRightToLeft: Bool
    let colorScheme: ColorScheme
    let pages: [Page]

    private var indexesFromLeft: [Int] {
        let indexes = Array(0..<pageCount)
        return isRightToLeft ? indexes.reversed() : indexes
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(indexesFromLeft, id: \.self) { index in
                pages[index]
                    .frame(width: pageSize.width, height: pageSize.height)
                    .clipped()
            }
        }
        .frame(width: pageSize.width * CGFloat(pageCount), height: pageSize.height, alignment: .leading)
        // The row is ordered by hand above: do not let SwiftUI mirror it again.
        .environment(\.layoutDirection, .leftToRight)
        // This hosting controller is not in the SwiftUI hierarchy of the feed, so it does not inherit its
        // environment.
        .environment(\.colorScheme, colorScheme)
        .edgesIgnoringSafeArea(.all)
    }
}
