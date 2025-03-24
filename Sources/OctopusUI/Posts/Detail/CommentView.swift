//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct CommentView: View {
    @Environment(\.octopusTheme) private var theme
    let comment: PostDetailViewModel.Comment
    let displayProfile: (String) -> Void
    let deleteComment: (String) -> Void
    let toggleLike: (String) -> Void
    let displayContentModeration: (String) -> Void

    @State private var openActions = false
    @State private var displayDeleteAlert = false

    @State private var liveMeasures: LiveMeasures = .init(aggregatedInfo: .empty, userInteractions: .empty)

    var body: some View {
        HStack(alignment: .top) {
            OpenProfileButton(author: comment.author, displayProfile: displayProfile) {
                AuthorAvatarView(avatar: comment.author.avatar)
                    .frame(width: 32, height: 32)
            }
            VStack(spacing: 0) {
                VStack {
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            OpenProfileButton(author: comment.author, displayProfile: displayProfile) {
                                comment.author.name.textView
                                    .font(theme.fonts.caption1)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.colors.gray900)
                            }
                            Circle()
                                .frame(width: 2, height: 2)
                                .foregroundColor(theme.colors.gray900)
                            Text(comment.relativeDate)
                                .font(theme.fonts.caption1)
                                .foregroundColor(theme.colors.gray500)
                            Spacer()
                            if comment.canBeDeleted || comment.canBeModerated {
                                if #available(iOS 14.0, *) {
                                    Menu(content: {
                                        if comment.canBeDeleted {
                                            Button(action: { displayDeleteAlert = true }) {
                                                Label(L10n("Comment.Delete.Button"), systemImage: "trash")
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        if comment.canBeModerated {
                                            Button(action: { displayContentModeration(comment.uuid) }) {
                                                Label(L10n("Moderation.Content.Button"), systemImage: "flag")
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }, label: {
                                        Image(.more)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(theme.colors.gray500)
                                    })
                                    .buttonStyle(.plain)
                                } else {
                                    Button(action: { openActions = true }) {
                                        Image(.more)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(theme.colors.gray500)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if let text = comment.text?.nilIfEmpty {
                            RichText(text)
                                .font(theme.fonts.body2)
                                .lineSpacing(4)
                                .foregroundColor(theme.colors.gray900)
                        }
                    }.padding(8)
                    if let image = comment.image {
                        AsyncCachedImage(
                            url: image.url, cache: .content,
                            placeholder: {
                                theme.colors.gray200
                                    .aspectRatio(
                                        image.size.width/image.size.height,
                                        contentMode: .fit)
                                    .clipped()
                            },
                            content: { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(12)
                            })
                    }
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerSize: CGSize(width: 12, height: 12))
                        .foregroundColor(theme.colors.gray300)
                )

                let userInteractions = liveMeasures.userInteractions
                let aggregatedInfo = liveMeasures.aggregatedInfo
                Button(action: { toggleLike(comment.uuid) }) {
                    Image(userInteractions.hasLiked ? .AggregatedInfo.likeActivated : .AggregatedInfo.like)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(userInteractions.hasLiked ? theme.colors.like : theme.colors.gray700)
                    if aggregatedInfo.likeCount > 0 {
                        Text(verbatim: "\(aggregatedInfo.likeCount)")
                            .font(theme.fonts.caption1)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.gray700)
                    } else {
                        Text("Content.AggregatedInfo.Like", bundle: .module)
                            .font(theme.fonts.caption1)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.gray700)
                    }
                }
                .buttonStyle(.plain)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .id("comment-\(comment.uuid)")
        .actionSheet(isPresented: $openActions) {
            ActionSheet(title: Text("ActionSheet.Title", bundle: .module), buttons: actionSheetContent)
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Comment.Delete.Confirmation.Title", bundle: .module),
                    isPresented: $displayDeleteAlert) {
                        Button(role: .cancel, action: {}, label: { Text("Common.Cancel", bundle: .module) })
                        Button(role: .destructive, action: { deleteComment(comment.uuid) },
                               label: { Text("Common.Delete", bundle: .module) })
                    }
            } else {
                $0.alert(isPresented: $displayDeleteAlert) {
                    Alert(title: Text("Comment.Delete.Confirmation.Title",
                                      bundle: .module),
                          primaryButton: .default(Text("Common.Cancel", bundle: .module)),
                          secondaryButton: .destructive(
                            Text("Common.Delete", bundle: .module),
                            action: { deleteComment(comment.uuid) }
                          )
                    )
                }
            }
        }
        .onReceive(comment.liveMeasures) {
            liveMeasures = $0
        }
    }

    var actionSheetContent: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        if comment.canBeDeleted {
            buttons.append(ActionSheet.Button.destructive(Text("Comment.Delete.Button", bundle: .module)) {
                displayDeleteAlert = true
            })
        }
        if comment.canBeModerated {
            buttons.append(ActionSheet.Button.destructive(Text("Moderation.Content.Button", bundle: .module)) {
                displayContentModeration(comment.uuid)
            })
        }

        buttons.append(.cancel())
        return buttons
    }
}
