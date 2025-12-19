//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension Compat {
    struct ScrollView<Content: View>: View {
        let axes: Axis.Set
        let showIndicators: Bool
        @Binding var scrollToTop: Bool
        @Binding var scrollToBottom: Bool
        @Binding var scrollToId: String?
        let idAnchor: UnitPoint?
        let preventScrollIfContentFits: Bool
        let canScrollToExtremities: Bool
        @State private var refreshAction: (@Sendable () async -> Void)?
        @ViewBuilder let content: Content

        init(_ axes: Axis.Set = .vertical,
             showIndicators: Bool = true,
             scrollToTop: Binding<Bool> = .constant(false),
             scrollToBottom: Binding<Bool> = .constant(false),
             scrollToId: Binding<String?> = .constant(nil),
             idAnchor: UnitPoint? = nil,
             preventScrollIfContentFits: Bool = true,
             canScrollToExtremities: Bool = true,
             refreshAction: (@Sendable () async -> Void)? = nil,
             minTime: TimeInterval = 0.75,
             @ViewBuilder content: () -> Content) {
            self.axes = axes
            self.showIndicators = showIndicators
            self._scrollToTop = scrollToTop
            self._scrollToBottom = scrollToBottom
            self._scrollToId = scrollToId
            self.idAnchor = idAnchor
            self.preventScrollIfContentFits = preventScrollIfContentFits
            self.canScrollToExtremities = canScrollToExtremities
            if let refreshAction {
                self._refreshAction = State(initialValue: {
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
                    canScrollToExtremities: canScrollToExtremities,
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
            } else if #available(iOS 14.0, *) {
                ScrollViewIOS14(axes: axes,
                                showIndicators: showIndicators,
                                scrollToTop: $scrollToTop,
                                scrollToBottom: $scrollToBottom,
                                scrollToId: $scrollToId,
                                idAnchor: idAnchor,
                                canScrollToExtremities: canScrollToExtremities,
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
        let canScrollToExtremities: Bool
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
                    withAnimation {
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
        let canScrollToExtremities: Bool
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
                            withAnimation {
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
    private struct ScrollViewIOS13<Content:View>: View {
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
