//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Testing
import UIKit
@testable import OctopusUI

/// The home screen keeps what sits at its bottom, like the "write a post" button, off the bottom edge of the screen:
/// when it touches that edge with no safe area there (a device with a home button, no tab bar), a margin is added to
/// the bottom safe area inset given by the integrator. A screen that ends above something gets nothing.
@MainActor
struct ScreenEdgeMarginTests {

    @Test func marginIsAddedWhenTheContainerTouchesTheScreenBottom() {
        #expect(InsetableMainNavigationView.bottomInset(
            bottomSafeAreaInset: 0, containerBottomInset: 0, touchesScreenBottom: true) == 16)
        #expect(InsetableMainNavigationView.bottomInset(
            bottomSafeAreaInset: 10, containerBottomInset: 0, touchesScreenBottom: true) == 26)
    }

    @Test func nothingIsAddedAboveAHomeIndicatorOrATabBar() {
        // Home indicator of an iPad, of an iPhone, then a translucent tab bar on a device with a home button.
        for containerInset: CGFloat in [20, 34, 49] {
            #expect(InsetableMainNavigationView.bottomInset(
                bottomSafeAreaInset: 0, containerBottomInset: containerInset, touchesScreenBottom: true) == 0)
            #expect(InsetableMainNavigationView.bottomInset(
                bottomSafeAreaInset: 10, containerBottomInset: containerInset, touchesScreenBottom: true) == 10)
        }
    }

    @Test func nothingIsAddedWhenTheContainerEndsAboveTheScreenBottom() {
        // An opaque tab bar, a bar of the host app or the bottom of a sheet under the container.
        #expect(InsetableMainNavigationView.bottomInset(
            bottomSafeAreaInset: 0, containerBottomInset: 0, touchesScreenBottom: false) == 0)
        #expect(InsetableMainNavigationView.bottomInset(
            bottomSafeAreaInset: 10, containerBottomInset: 0, touchesScreenBottom: false) == 10)
    }

    @Test func nothingIsAddedWhileTheContainerIsNotMeasured() {
        #expect(InsetableMainNavigationView.bottomInset(
            bottomSafeAreaInset: 0, containerBottomInset: nil, touchesScreenBottom: true) == 0)
        #expect(InsetableMainNavigationView.bottomInset(
            bottomSafeAreaInset: 0, containerBottomInset: 0, touchesScreenBottom: nil) == 0)
        #expect(InsetableMainNavigationView.bottomInset(
            bottomSafeAreaInset: 10, containerBottomInset: nil, touchesScreenBottom: nil) == 10)
    }

    @Test func viewTouchesTheScreenBottomOnlyDownToAWindowWithNoBottomInset() {
        let window = CGRect(x: 0, y: 0, width: 375, height: 667)

        // Down to the bottom of a home-button device's window.
        #expect(InsetableMainNavigationView.touchesScreenBottom(
            frameInWindow: window, windowBounds: window, windowBottomInset: 0))
        // Pixel rounding.
        #expect(InsetableMainNavigationView.touchesScreenBottom(
            frameInWindow: CGRect(x: 0, y: 0, width: 375, height: 666.67), windowBounds: window, windowBottomInset: 0))
        // Above a tab bar, a bar of the host app or in a sheet.
        #expect(!InsetableMainNavigationView.touchesScreenBottom(
            frameInWindow: CGRect(x: 0, y: 0, width: 375, height: 618), windowBounds: window, windowBottomInset: 0))
        // A window with a home indicator, even for a view that ignores the safe area.
        #expect(!InsetableMainNavigationView.touchesScreenBottom(
            frameInWindow: window, windowBounds: window, windowBottomInset: 34))
    }

    @Test func contentGetsTheMarginWhenItTouchesTheScreenBottom() async throws {
        guard #available(iOS 16.4, *) else { return }
        let inset = InsetBox()
        // A window that stops above the home indicator of the simulator has no bottom safe area, like the window of
        // a device with a home button.
        let window = makeWindow(reportingTo: inset, containerHeight: nil) { host in
            host.safeAreaRegions = []
        }
        defer { window.isHidden = true }

        try await waitUntil { inset.value == InsetableMainNavigationView.screenEdgeMargin }
        try await expectStable(inset)
    }

    @Test func contentGetsNothingWhenItEndsAboveTheScreenBottom() async throws {
        guard #available(iOS 16.4, *) else { return }
        let inset = InsetBox()
        let window = makeWindow(reportingTo: inset, containerHeight: 300) { host in
            host.safeAreaRegions = []
        }
        defer { window.isHidden = true }

        try await waitUntil { inset.value == 0 }
        try await expectStable(inset)
    }

    @Test func contentKeepsTheSafeAreaOfItsContainerWhenItHasOne() async throws {
        let inset = InsetBox()
        var hostView: UIView?
        let window = makeWindow(reportingTo: inset, containerHeight: nil) { host in
            host.additionalSafeAreaInsets.bottom = 34
            hostView = host.view
        }
        defer { window.isHidden = true }
        let host = try #require(hostView)

        // Neither the margin nor the spacing SwiftUI puts before an inset is added.
        try await waitUntil { inset.value != nil && inset.value == host.safeAreaInsets.bottom }
        #expect(host.safeAreaInsets.bottom >= 34)
        try await expectStable(inset)
    }

    @Test func measureIsKeptWhileAParentIsTransformed() async throws {
        let (window, container, view, reported) = makeMeasuredView()
        defer { window.isHidden = true }
        try await waitUntil { reported.values == [true] }

        // What a page sheet does to the screen under it on iOS 15 to 18.
        container.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        #expect(!InsetableMainNavigationView.touchesScreenBottom(
            frameInWindow: view.convert(view.bounds, to: window), windowBounds: window.bounds, windowBottomInset: 0))
        view.report()
        // The sheet is dismissed: nothing lays the view out again.
        container.transform = .identity

        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(reported.values == [true])
    }

    @Test func measureIsKeptWhileTheViewIsOutOfItsWindow() async throws {
        let (window, container, view, reported) = makeMeasuredView()
        defer { window.isHidden = true }
        try await waitUntil { reported.values == [true] }

        // A screen pushed over it, then popped.
        view.removeFromSuperview()
        try await Task.sleep(nanoseconds: 200_000_000)
        container.addSubview(view)

        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(reported.values == [true])
    }

    @Test func firstMeasureWaitsForTheLayout() async throws {
        let window = makeVisibleWindow()
        defer { window.isHidden = true }
        let reported = ReportedValues()
        // A representable view moves to its window before it has a size.
        let view = ScreenBottomView(frame: .zero)
        view.onChange = { reported.values.append($0) }
        window.rootViewController?.view.addSubview(view)
        try await Task.sleep(nanoseconds: 200_000_000)

        view.frame = window.bounds
        view.layoutIfNeeded()

        try await waitUntil { !reported.values.isEmpty }
        try await Task.sleep(nanoseconds: 200_000_000)
        // A measure taken without a size would have said it does not touch the bottom, then changed.
        #expect(reported.values == [true])
    }

    @Test func noMeasureIsTakenBelowTheWindow() async throws {
        let window = makeVisibleWindow()
        defer { window.isHidden = true }
        let reported = ReportedValues()
        // Where UIKit starts a sheet it presents, before it slides it up to a frame that ends above the bottom.
        let view = ScreenBottomView(frame: CGRect(x: 0, y: window.bounds.maxY, width: 390, height: 300))
        view.onChange = { reported.values.append($0) }
        window.rootViewController?.view.addSubview(view)
        try await Task.sleep(nanoseconds: 200_000_000)

        view.frame.origin.y = 50
        view.report()

        try await waitUntil { !reported.values.isEmpty }
        try await Task.sleep(nanoseconds: 200_000_000)
        // A measure taken below the window would have said it touches the bottom, then changed.
        #expect(reported.values == [false])
    }

    @Test func viewIsTransformedWhenOneOfItsParentsIs() {
        let parent = UIView()
        let view = UIView()
        parent.addSubview(view)
        #expect(!ScreenBottomView.hasTransformedAncestor(view))

        parent.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        #expect(ScreenBottomView.hasTransformedAncestor(view))
    }

    /// A `ScreenBottomView` filling a container that fills a visible window, 400pt high so that it has no bottom safe
    /// area, with the measures it reports.
    private func makeMeasuredView() -> (UIWindow, UIView, ScreenBottomView, ReportedValues) {
        let window = makeVisibleWindow()
        let container = UIView(frame: window.bounds)
        let view = ScreenBottomView(frame: container.bounds)
        let reported = ReportedValues()
        view.onChange = { reported.values.append($0) }
        container.addSubview(view)
        window.rootViewController?.view.addSubview(container)
        return (window, container, view, reported)
    }

    /// A visible window, 400pt high so that it has no bottom safe area, with an empty root view controller.
    private func makeVisibleWindow() -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 400))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        return window
    }

    /// Lets the measures of the container come in, then checks the inset did not move: a margin added late or a
    /// measure that feeds back into itself would.
    private func expectStable(_ inset: InsetBox) async throws {
        let measured = inset.value
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(inset.value == measured)
    }

    /// A visible window, 400pt high so that it stays clear of the simulator's home indicator, showing content under
    /// the home screen's inset modifier, with no inset from the integrator, that reports its bottom safe area inset
    /// into `box`. The content fills the window, or is `containerHeight` high from its top. The test host runs
    /// without scenes, so the window is attached to the screen directly.
    private func makeWindow(reportingTo box: InsetBox, containerHeight: CGFloat?,
                            configure: (UIHostingController<AnyView>) -> Void) -> UIWindow {
        let content = GeometryReader { proxy in
            Color.clear.onValueChanged(of: proxy.safeAreaInsets.bottom, initial: true) { box.value = $0 }
        }
        .insetableMainNavigationView(bottomSafeAreaInset: 0, keepsMarginFromScreenEdge: true)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 400))
        let host = UIHostingController(rootView: AnyView(content))
        configure(host)
        if let containerHeight {
            let root = UIViewController()
            root.addChild(host)
            host.view.frame = CGRect(x: 0, y: 0, width: 390, height: containerHeight)
            root.view.addSubview(host.view)
            host.didMove(toParent: root)
            window.rootViewController = root
        } else {
            window.rootViewController = host
        }
        window.makeKeyAndVisible()
        return window
    }
}

@MainActor
private final class InsetBox {
    var value: CGFloat?
}

@MainActor
private final class ReportedValues {
    var values: [Bool] = []
}
