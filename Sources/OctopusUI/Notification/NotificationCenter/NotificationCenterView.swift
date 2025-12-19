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

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    init(viewModel: NotificationCenterViewModel) {
        _viewModel = Compat.StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ContentView(
            showPushNotificationSetting: viewModel.showPushNotificationSetting,
            pushNotificationEnabled: $viewModel.pushNotificationEnabled,
            notifications: viewModel.notifications,
            action: { notification in
                viewModel.markNotificationAsRead(notifId: notification.uuid)
                if let action = notification.action {
                    switch action {
                    case let .open(contentsToOpen):
                        navigator.path.append(contentsOf: contentsToOpen.map { $0.mainFlowScreen })
                    }
                }
            })
        .onAppear {
            viewModel.viewDidAppear()
        }
        .onDisappear {
            viewModel.viewDidDisappear()
        }
        .compatAlert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
        .onReceive(viewModel.$displayableError) { error in
            guard let error else { return }
            displayableError = error
            displayError = true
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let showPushNotificationSetting: Bool
    @Binding var pushNotificationEnabled: Bool
    let notifications: [DisplayableNotification]
    let action: (DisplayableNotification) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if showPushNotificationSetting {
                PushNotificationSettingView(pushNotificationEnabled: $pushNotificationEnabled)
                theme.colors.gray300.frame(height: 1)
            }
            if !notifications.isEmpty {
                NotificationListView(notifications: notifications, action: action)
            } else {
                NoNotificationView()
            }
        }
    }
}

private struct PushNotificationSettingView: View {
    @Environment(\.octopusTheme) private var theme
    @Binding var pushNotificationEnabled: Bool

    var body: some View {
        HStack {
            Toggle(isOn: $pushNotificationEnabled) {
                Text("Notifications.Settings.Push.Enable", bundle: .module)
                    .font(theme.fonts.body2)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.gray900)
            }
            .toggleStyle(.octopus)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
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
            .frame(minHeight: 48)
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
            AuthorAvatarView(avatar: Author(profile: profile, gamificationLevel: nil).avatar)
        }
    }
}

private struct NoNotificationView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        VStack {
            Spacer().frame(height: 54)
            Image(res: .bell)
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
