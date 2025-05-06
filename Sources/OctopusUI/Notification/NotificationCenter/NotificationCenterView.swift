//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct NotificationCenterView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Compat.StateObject private var viewModel: NotificationCenterViewModel

    init(viewModel: NotificationCenterViewModel) {
        _viewModel = Compat.StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ContentView(
            notifications: viewModel.notifications,
            action: { notification in
                viewModel.markNotificationAsRead(notifId: notification.uuid)
                if let action = notification.action {
                    switch action {
                    case let .open(contentsToOpen):
                        guard let lastContentToOpen = contentsToOpen.last else { break }
                        switch lastContentToOpen.kind {
                        case .post:
                            navigator.push(.postDetail(postId: lastContentToOpen.contentId,
                                                       scrollToMostRecentComment: false))
                        case .comment:
                            navigator.push(.commentDetail(commentId: lastContentToOpen.contentId, reply: false,
                                                         replyToScrollTo: nil))
                        case .reply:
                            // we need to know which is the parent comment for the reply
                            guard let comment = contentsToOpen.last(where: { $0.kind == .comment }) else { break }
                            navigator.push(.commentDetail(commentId: comment.contentId, reply: false,
                                                          replyToScrollTo: lastContentToOpen.contentId))
                        }
                    }
                }
            })
        .onAppear {
            viewModel.viewDidAppear()
        }
        .onDisappear {
            viewModel.viewDidDisappear()
        }
    }
}

private struct ContentView: View {
    let notifications: [DisplayableNotification]
    let action: (DisplayableNotification) -> Void

    var body: some View {
        if !notifications.isEmpty {
            NotificationListView(notifications: notifications, action: action)
        } else {
            NoNotificationView()
        }
    }
}

private struct NotificationListView: View {
    let notifications: [DisplayableNotification]
    let action: (DisplayableNotification) -> Void

    var body: some View {
        VStack(spacing: 1) {
            ForEach(notifications, id: \.uuid) { notification in
                NotificationCell(notification: notification, action: action)
            }
        }
    }
}

private struct NotificationCell: View {
    @Environment(\.octopusTheme) private var theme
    let notification: DisplayableNotification
    let action: (DisplayableNotification) -> Void

    var body: some View {
        Button(action: { action(notification) }) {
            HStack(spacing: 16) {
                NotificationImageView(thumbnails: notification.thumbnails)
                VStack(alignment: .leading, spacing: 0) {
                    RichText(notification.text)
                        .font(theme.fonts.body2.weight(.regular))
                        .foregroundColor(theme.colors.gray900)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(notification.relativeDate)
                        .font(theme.fonts.caption1)
                        .foregroundColor(theme.colors.gray700)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(notification.isRead ? Color.clear : theme.colors.primaryLowContrast)
        }
        .buttonStyle(.plain)
    }
}

private struct NotificationImageView: View {
    let thumbnails: [OctoNotification.Thumbnail]

    var body: some View {
        switch thumbnails.count {
        case 0: EmptyView()
        case 1:
            ThumbnailImageView(thumbnail: thumbnails[0])
                .frame(width: 48, height: 48)
        default:
            ZStack(alignment: .topLeading) {
                ThumbnailImageView(thumbnail: thumbnails[0])
                    .frame(width: 32, height: 32)
                ThumbnailImageView(thumbnail: thumbnails[1])
                    .frame(width: 32, height: 32)
                    .offset(x: 16, y: 20)
            }
            .frame(width: 48, height: 52, alignment: .topLeading)
        }
    }
}

private struct ThumbnailImageView: View {
    let thumbnail: OctoNotification.Thumbnail

    var body: some View {
        switch thumbnail {
        case let .profile(profile):
            AuthorAvatarView(avatar: Author(profile: profile).avatar)
        }
    }
}

private struct NoNotificationView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        VStack {
            Spacer().frame(height: 54)
            Image(.bell)
                .resizable()
                .frame(width: 32, height: 32)
            Text("Notifications.List.Empty", bundle: .module)
                .font(theme.fonts.body2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(theme.colors.gray500)
    }
}
