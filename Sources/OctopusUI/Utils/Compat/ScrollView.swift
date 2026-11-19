//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension Compat {
    /// A one-shot request to scroll to the view identified by `id`. Unlike `scrollToId`, which uses the
    /// scroll view's fixed `idAnchor`, each request carries its own anchor: `nil` scrolls the minimum
    /// amount that makes the view visible. The scroll view resets the binding to `nil` once the request
    /// is handled, so the same request can be sent again. On iOS 13, where no `ScrollViewReader` is
    /// available, requests are ignored.
    struct ScrollRequest: Equatable {
        let id: String
        let anchor: UnitPoint?
        /// Whether the scroll is animated. A request that keeps a row in place while content is inserted above it
        /// is not: the member should not see the list move at all.
        var animated = true
        /// A view scrolled to first, with the same anchor. The scroll to `id` then moves on from it, or leaves the
        /// scroll view there when that view is out of its reach: a lazy stack scrolls to its own children only, not to
        /// the views nested in a child it has not laid out.
        var fallbackId: String?
    }

    struct ScrollView<Content: View>: View {
        let axes: Axis.Set
        let showIndicators: Bool
        @Binding var scrollToTop: Bool
        @Binding var scrollToBottom: Bool
        @Binding var scrollToId: String?
        let idAnchor: UnitPoint?
        @Binding var scrollRequest: ScrollRequest?
        let preventScrollIfContentFits: Bool
        let canScrollToExtremities: Bool
        let animatesScrollToBottom: Bool
        @State private var refreshAction: (@Sendable () async -> Void)?
        @ViewBuilder let content: Content

        init(_ axes: Axis.Set = .vertical,
             showIndicators: Bool = true,
             scrollToTop: Binding<Bool> = .constant(false),
             scrollToBottom: Binding<Bool> = .constant(false),
             scrollToId: Binding<String?> = .constant(nil),
             idAnchor: UnitPoint? = nil,
             scrollRequest: Binding<ScrollRequest?> = .constant(nil),
             preventScrollIfContentFits: Bool = true,
             canScrollToExtremities: Bool = true,
             animatesScrollToBottom: Bool = true,
             refreshAction: (@Sendable () async -> Void)? = nil,
             minTime: TimeInterval = 0.75,
             @ViewBuilder content: () -> Content) {
            self.axes = axes
            self.showIndicators = showIndicators
            self._scrollToTop = scrollToTop
            self._scrollToBottom = scrollToBottom
            self._scrollToId = scrollToId
            self.idAnchor = idAnchor
            self._scrollRequest = scrollRequest
            self.preventScrollIfContentFits = preventScrollIfContentFits
            self.canScrollToExtremities = canScrollToExtremities
            self.animatesScrollToBottom = animatesScrollToBottom
            if let refreshAction {
                self._refreshAction = State(initialValue: { @Sendable in
                    let refreshTask = Task { await refreshAction() }
                    let durationTask = Task {
                        try? await Task.sleep(nanoseconds: UInt64(minTime * 1_000_000_000))
                    }

                    await refreshTask.value
                    await durationTask.value
                })
            } else {
                self._refreshAction = State(initialValue: nil)
            }
            self.content = content()
        }

        var body: some View {
            if #available(iOS 15.0, *) {
                ScrollViewIOS15(
                    axes: axes,
                    showIndicators: showIndicators,
                    scrollToTop: $scrollToTop,
                    scrollToBottom: $scrollToBottom,
                    scrollToId: $scrollToId,
                    idAnchor: idAnchor,
                    scrollRequest: $scrollRequest,
                    canScrollToExtremities: canScrollToExtremities,
                    animatesScrollToBottom: animatesScrollToBottom,
                    refreshAction: refreshAction) {
                        content
                    }
                    .modify {
                        if #available(iOS 16.4, *), preventScrollIfContentFits {
                            $0.scrollBounceBehavior(.basedOnSize)
                        } else {
                            $0
                        }
                    }
            } else {
                scrollViewBeforeIOS15
            }
        }

        // Out of `body`: chained as `else if` after the iOS 15 check, this check is reported as unnecessary when
        // the deployment target is iOS 15 or later (the one Xcode 27 builds for), while hosts with an older Xcode
        // still run this code on iOS 13.
        @ViewBuilder
        private var scrollViewBeforeIOS15: some View {
            if #available(iOS 14.0, *) {
                ScrollViewIOS14(axes: axes,
                                showIndicators: showIndicators,
                                scrollToTop: $scrollToTop,
                                scrollToBottom: $scrollToBottom,
                                scrollToId: $scrollToId,
                                idAnchor: idAnchor,
                                scrollRequest: $scrollRequest,
                                canScrollToExtremities: canScrollToExtremities,
                                animatesScrollToBottom: animatesScrollToBottom,
                                refreshAction: refreshAction) {
                    content
                }
            } else {
                ScrollViewIOS13(axes: axes, showIndicators: showIndicators, refreshAction: refreshAction) {
                    content
                }
            }
        }
    }

    /// A ScrollView that uses `ScrollViewReader` to scroll and `.refreshable` for the pull to refresh
    /// Available starting iOS 15 (due to refreshable)
    @available(iOS 15.0, *)
    private struct ScrollViewIOS15<Content: View>: View {
        let axes: Axis.Set
        let showIndicators: Bool
        @Binding var scrollToTop: Bool
        @Binding var scrollToBottom: Bool
        @Binding var scrollToId: String?
        let idAnchor: UnitPoint?
        @Binding var scrollRequest: ScrollRequest?
        let canScrollToExtremities: Bool
        let animatesScrollToBottom: Bool
        let refreshAction: (@Sendable () async -> Void)?
        @ViewBuilder let content: Content

        private let topId = "invisibleTopId"
        private let bottomId = "invisibleBottomId"

        var body: some View {
            ScrollViewReader { reader in
                SwiftUI.ScrollView(axes, showsIndicators: showIndicators) {
                    // TODO Djavan: the caller should implement this instead of doing it here because it creates an
                    // implicit VStack
                    if canScrollToExtremities {
                        VStack(spacing: 0) {
                            Color.white.opacity(0.0001)
                                .frame(height: 1)
                                .id(topId)

                            content

                            Color.white.opacity(0.0001)
                                .frame(height: 1)
                                .id(bottomId)
                        }
                    } else {
                        content
                    }
                }
                .modify {
                    if let refreshAction {
                        $0.refreshable(action: refreshAction)
                    } else {
                        $0
                    }
                }
                .onChange(of: scrollToTop) {
                    guard $0 else { return }
                    withAnimation {
                        reader.scrollTo(topId, anchor: .top)
                    }
                    scrollToTop = false
                }
                .onChange(of: scrollToBottom) {
                    guard $0 else { return }
                    withAnimation(animatesScrollToBottom ? .default : nil) {
                        reader.scrollTo(bottomId, anchor: .bottom)
                    }
                    scrollToBottom = false
                }
                .onChange(of: scrollToId) {
                    guard let id = $0 else { return }
                    withAnimation {
                        reader.scrollTo(id, anchor: idAnchor)
                    }
                    scrollToId = nil
                }
                .onChange(of: scrollRequest) {
                    guard let request = $0 else { return }
                    if request.animated {
                        withAnimation {
                            reader.scroll(to: request)
                        }
                    } else {
                        reader.scroll(to: request)
                    }
                    scrollRequest = nil
                }
            }
        }
    }

    /// A ScrollView that uses `ScrollViewReader` to scroll and a custom solution for the pull to refresh
    /// Available starting iOS 14 (due to ScrollViewReader)
    @available(iOS 14.0, *)
    private struct ScrollViewIOS14<Content: View>: View {
        let axes: Axis.Set
        let showIndicators: Bool
        @Binding var scrollToTop: Bool
        @Binding var scrollToBottom: Bool
        @Binding var scrollToId: String?
        let idAnchor: UnitPoint?
        @Binding var scrollRequest: ScrollRequest?
        let canScrollToExtremities: Bool
        let animatesScrollToBottom: Bool
        let refreshAction: (@Sendable () async -> Void)?
        @ViewBuilder let content: Content

        @State private var isCurrentlyRefreshing = false

        private let topId = "invisibleTopId"
        private let bottomId = "invisibleBottomId"

        var body: some View {
            GeometryReader { geometry in
                VStack {
                    if isCurrentlyRefreshing {
                        HStack {
                            Spacer()
                            if #available(iOS 14.0, *) {
                                ProgressView()
                            }
                            Spacer()
                        }.padding()
                    }
                    ScrollViewReader { reader in
                        SwiftUI.ScrollView(axes, showsIndicators: showIndicators) {
                            // TODO Djavan: the caller should implement this instead of doing it here because it creates an
                            // implicit VStack
                            if canScrollToExtremities {
                                Color(UIColor.systemBackground)
                                    .frame(height: 1)
                                    .id(topId)
                            }
                            content
                                .anchorPreference(key: OffsetPreferenceKey.self, value: .top) {
                                    geometry[$0].y
                                }
                            if canScrollToExtremities {
                                Color(UIColor.systemBackground)
                                    .frame(height: 1)
                                    .id(bottomId)
                            }
                        }
                        .onChange(of: scrollToTop) {
                            guard $0 else { return }
                            withAnimation {
                                reader.scrollTo(topId, anchor: .top)
                            }
                            scrollToTop = false
                        }
                        .onChange(of: scrollToBottom) {
                            guard $0 else { return }
                            withAnimation(animatesScrollToBottom ? .default : nil) {
                                reader.scrollTo(bottomId, anchor: .bottom)
                            }
                            scrollToBottom = false
                        }
                        .onChange(of: scrollToId) {
                            guard let id = $0 else { return }
                            withAnimation {
                                reader.scrollTo(id, anchor: idAnchor)
                            }
                            scrollToId = nil
                        }
                        .onChange(of: scrollRequest) {
                            guard let request = $0 else { return }
                            if request.animated {
                                withAnimation {
                                    reader.scroll(to: request)
                                }
                            } else {
                                reader.scroll(to: request)
                            }
                            scrollRequest = nil
                        }
                        .onPreferenceChange(OffsetPreferenceKey.self) { [$isCurrentlyRefreshing] offset in
                            guard let refreshAction else { return }
                            guard !$isCurrentlyRefreshing.wrappedValue else { return }
                            guard offset > refreshThreshold else { return }
                            $isCurrentlyRefreshing.wrappedValue = true
                            Task {
                                await refreshAction()
                                $isCurrentlyRefreshing.wrappedValue = false
                            }
                        }
                    }
                }
            }
        }
    }

    /// A ScrollView that uses a custom solution for the pull to refresh
    /// - Note: this view cannot scroll to top.
    private struct ScrollViewIOS13<Content: View>: View {
        let axes: Axis.Set
        let showIndicators: Bool
        let refreshAction: (@Sendable () async -> Void)?
        @ViewBuilder let content: Content

        @State private var isCurrentlyRefreshing = false

        var body: some View {
            GeometryReader { geometry in
                VStack {
                    if isCurrentlyRefreshing {
                        HStack {
                            Spacer()
                            if #available(iOS 14.0, *) {
                                ProgressView()
                            }
                            Spacer()
                        }.padding()
                    }
                    SwiftUI.ScrollView(axes, showsIndicators: showIndicators) {
                        content
                            .anchorPreference(key: OffsetPreferenceKey.self, value: .top) {
                                geometry[$0].y
                            }
                    }
                    .onPreferenceChange(OffsetPreferenceKey.self) { [$isCurrentlyRefreshing] offset in
                        guard let refreshAction else { return }
                        guard !$isCurrentlyRefreshing.wrappedValue else { return }
                        guard offset > refreshThreshold else { return }
                        $isCurrentlyRefreshing.wrappedValue = true
                        Task {
                            await refreshAction()
                            $isCurrentlyRefreshing.wrappedValue = false
                        }
                    }
                }
            }
        }
    }
}

private let refreshThreshold: CGFloat = 100.0

private struct OffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

@available(iOS 14.0, *)
private extension ScrollViewProxy {
    func scroll(to request: Compat.ScrollRequest) {
        if let fallbackId = request.fallbackId {
            scrollTo(fallbackId, anchor: request.anchor)
        }
        scrollTo(request.id, anchor: request.anchor)
    }
}
