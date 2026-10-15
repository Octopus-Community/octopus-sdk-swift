//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

struct DefaultAvatarProfileMappingTests {
    static let color = Com_Octopuscommunity_DefaultAvatar.with {
        $0.color = .with {
            $0.backgroundHex = "#3366CC"
            $0.initialsHex = "#FFFFFF"
        }
    }
    static let image = Com_Octopuscommunity_DefaultAvatar.with { $0.imageURL = "https://cdn.example.com/a1b2.jpg" }
    static let imageUrl = URL(string: "https://cdn.example.com/a1b2.jpg")!

    // MARK: MinimalProfile

    @Test func minimalProfileReadsTheColor() {
        let profile = MinimalProfile(from: Com_Octopuscommunity_MinimalProfile.with {
            $0.profileID = "p1"
            $0.nickname = "Zoé"
            $0.defaultAvatar = Self.color
        })
        #expect(profile.defaultAvatar == .color(backgroundHex: "#3366CC", initialsHex: "#FFFFFF"))
        #expect(profile.avatarUrl == nil)
    }

    @Test func minimalProfileIgnoresTheLegacyCopyOfTheDefaultImage() {
        let profile = MinimalProfile(from: Com_Octopuscommunity_MinimalProfile.with {
            $0.profileID = "p1"
            $0.nickname = "Zoé"
            $0.avatarURL = "https://cdn.example.com/a1b2.jpg"
            $0.defaultAvatar = Self.image
        })
        #expect(profile.defaultAvatar == .image(url: Self.imageUrl))
        #expect(profile.avatarUrl == nil)
    }

    @Test func minimalProfileWithoutDefaultKeepsItsPicture() {
        let profile = MinimalProfile(from: Com_Octopuscommunity_MinimalProfile.with {
            $0.profileID = "p1"
            $0.nickname = "Zoé"
            $0.avatarURL = "https://cdn.example.com/own.jpg"
        })
        #expect(profile.defaultAvatar == nil)
        #expect(profile.avatarUrl == URL(string: "https://cdn.example.com/own.jpg"))
    }

    /// A default this version cannot draw (a kind added to the contract later, an invalid value) is ignored, and the
    /// copy of the image the server makes for older SDKs is shown instead, as those SDKs do.
    @Test func minimalProfileWithAnUndrawableDefaultKeepsTheLegacyCopy() {
        let profile = MinimalProfile(from: Com_Octopuscommunity_MinimalProfile.with {
            $0.profileID = "p1"
            $0.nickname = "Zoé"
            $0.avatarURL = "https://cdn.example.com/a1b2.jpg"
            $0.defaultAvatar = Com_Octopuscommunity_DefaultAvatar()
        })
        #expect(profile.defaultAvatar == nil)
        #expect(profile.avatarUrl == Self.imageUrl)
    }

    @Test func minimalProfileWithAnUndrawableDefaultAndNoCopyFallsBackToTheComputedAvatar() {
        let profile = MinimalProfile(from: Com_Octopuscommunity_MinimalProfile.with {
            $0.profileID = "p1"
            $0.nickname = "Zoé"
            $0.defaultAvatar = .with {
                $0.color = .with {
                    $0.backgroundHex = "blue"
                    $0.initialsHex = "#FFFFFF"
                }
            }
        })
        #expect(profile.defaultAvatar == nil)
        #expect(profile.avatarUrl == nil)
    }

    @MainActor
    @Test(arguments: [
        DefaultAvatar.color(backgroundHex: "#3366CC", initialsHex: "#FFFFFF"),
        DefaultAvatar.image(url: URL(string: "https://cdn.example.com/a1b2.jpg")!),
    ])
    func minimalProfileEntityRoundTrip(avatar: DefaultAvatar) throws {
        let context = try ModelCoreDataStack(inRam: true).viewContext
        let entity = MinimalProfileEntity(context: context)
        entity.fill(with: MinimalProfile(uuid: "p1", nickname: "Zoé", defaultAvatar: avatar), context: context)
        #expect(MinimalProfile(from: entity).defaultAvatar == avatar)
    }

    /// Notification thumbnails write authors without replacing their secondary infos, but the avatar is primary:
    /// like the picture URL, a default the server no longer sends is removed.
    @MainActor
    @Test func minimalProfileEntityAlwaysReplacesTheDefault() throws {
        let context = try ModelCoreDataStack(inRam: true).viewContext
        let entity = MinimalProfileEntity(context: context)
        entity.fill(with: MinimalProfile(uuid: "p1", nickname: "Zoé", defaultAvatar: .image(url: Self.imageUrl)),
                    context: context)
        entity.fill(with: MinimalProfile(uuid: "p1", nickname: "Zoé"), replaceSecondaryInfosIfNil: false,
                    context: context)
        #expect(MinimalProfile(from: entity).defaultAvatar == nil)
    }

    // MARK: PublicProfile

    @Test func publicProfileIgnoresTheLegacyCopyOfTheDefaultImage() {
        let profile = StorableProfile(from: Com_Octopuscommunity_PublicProfile.with {
            $0.id = "p1"
            $0.pictureURL = "https://cdn.example.com/a1b2.jpg"
            $0.defaultAvatar = Self.image
        })
        #expect(profile.defaultAvatar == .image(url: Self.imageUrl))
        #expect(profile.pictureUrl == nil)
    }

    @Test func publicProfileReadsTheColor() {
        let profile = StorableProfile(from: Com_Octopuscommunity_PublicProfile.with {
            $0.id = "p1"
            $0.defaultAvatar = Self.color
        })
        #expect(profile.defaultAvatar == .color(backgroundHex: "#3366CC", initialsHex: "#FFFFFF"))
    }

    @Test func publicProfileWithoutDefaultKeepsItsPicture() {
        let profile = StorableProfile(from: Com_Octopuscommunity_PublicProfile.with {
            $0.id = "p1"
            $0.pictureURL = "https://cdn.example.com/own.jpg"
        })
        #expect(profile.defaultAvatar == nil)
        #expect(profile.pictureUrl == URL(string: "https://cdn.example.com/own.jpg"))
    }

    @Test func publicProfileWithAnUndrawableDefaultKeepsTheLegacyCopy() {
        let profile = StorableProfile(from: Com_Octopuscommunity_PublicProfile.with {
            $0.id = "p1"
            $0.pictureURL = "https://cdn.example.com/a1b2.jpg"
            $0.defaultAvatar = Com_Octopuscommunity_DefaultAvatar()
        })
        #expect(profile.defaultAvatar == nil)
        #expect(profile.pictureUrl == Self.imageUrl)
    }

    @Test func publicProfileWithAnImageDefaultAndNoCopyHasNoPicture() {
        let profile = StorableProfile(from: Com_Octopuscommunity_PublicProfile.with {
            $0.id = "p1"
            $0.defaultAvatar = Self.image
        })
        #expect(profile.defaultAvatar == .image(url: Self.imageUrl))
        #expect(profile.pictureUrl == nil)
    }

    // MARK: PrivateProfile

    @Test func privateProfileReadsTheDefault() {
        let profile = StorableCurrentUserProfile(from: Com_Octopuscommunity_PrivateProfile.with {
            $0.id = "p1"
            $0.defaultAvatar = Self.image
        }, userId: "u1")
        #expect(profile.defaultAvatar == .image(url: Self.imageUrl))
        #expect(profile.pictureUrl == nil)
    }

    @Test func privateProfileReadsTheColor() {
        let profile = StorableCurrentUserProfile(from: Com_Octopuscommunity_PrivateProfile.with {
            $0.id = "p1"
            $0.defaultAvatar = Self.color
        }, userId: "u1")
        #expect(profile.defaultAvatar == .color(backgroundHex: "#3366CC", initialsHex: "#FFFFFF"))
        #expect(profile.pictureUrl == nil)
    }

    @Test func privateProfileIgnoresTheLegacyCopyOfTheDefaultImage() {
        let profile = StorableCurrentUserProfile(from: Com_Octopuscommunity_PrivateProfile.with {
            $0.id = "p1"
            $0.pictureURL = "https://cdn.example.com/a1b2.jpg"
            $0.defaultAvatar = Self.image
        }, userId: "u1")
        #expect(profile.defaultAvatar == .image(url: Self.imageUrl))
        #expect(profile.pictureUrl == nil)
    }

    @Test func privateProfileWithAnUndrawableDefaultKeepsTheLegacyCopy() {
        let profile = StorableCurrentUserProfile(from: Com_Octopuscommunity_PrivateProfile.with {
            $0.id = "p1"
            $0.pictureURL = "https://cdn.example.com/a1b2.jpg"
            $0.defaultAvatar = Com_Octopuscommunity_DefaultAvatar()
        }, userId: "u1")
        #expect(profile.defaultAvatar == nil)
        #expect(profile.pictureUrl == Self.imageUrl)
    }

    @Test func privateProfileReadsTheDefaultIfPictureRemovedImage() {
        let profile = StorableCurrentUserProfile(from: Com_Octopuscommunity_PrivateProfile.with {
            $0.id = "p1"
            $0.pictureURL = "https://cdn.example.com/own.jpg"
            $0.defaultAvatarIfPictureRemoved = Self.image
        }, userId: "u1")
        #expect(profile.defaultAvatarIfPictureRemoved == .image(url: Self.imageUrl))
        #expect(profile.defaultAvatar == nil)
    }

    @Test func privateProfileReadsTheDefaultIfPictureRemovedColor() {
        let profile = StorableCurrentUserProfile(from: Com_Octopuscommunity_PrivateProfile.with {
            $0.id = "p1"
            $0.pictureURL = "https://cdn.example.com/own.jpg"
            $0.defaultAvatarIfPictureRemoved = Self.color
        }, userId: "u1")
        #expect(profile.defaultAvatarIfPictureRemoved == .color(backgroundHex: "#3366CC", initialsHex: "#FFFFFF"))
    }

    @Test func privateProfileWithoutDefaultIfPictureRemovedHasNone() {
        let profile = StorableCurrentUserProfile(from: Com_Octopuscommunity_PrivateProfile.with {
            $0.id = "p1"
            $0.pictureURL = "https://cdn.example.com/own.jpg"
        }, userId: "u1")
        #expect(profile.defaultAvatarIfPictureRemoved == nil)
    }

    @Test func privateProfileWithAnUndrawableDefaultIfPictureRemovedHasNone() {
        let profile = StorableCurrentUserProfile(from: Com_Octopuscommunity_PrivateProfile.with {
            $0.id = "p1"
            $0.pictureURL = "https://cdn.example.com/own.jpg"
            $0.defaultAvatarIfPictureRemoved = Com_Octopuscommunity_DefaultAvatar()
        }, userId: "u1")
        #expect(profile.defaultAvatarIfPictureRemoved == nil)
    }

    /// It only previews what removing the picture gives: the member's own picture stays what it is.
    @Test func privateProfileDefaultIfPictureRemovedNeverTouchesThePicture() {
        let profile = StorableCurrentUserProfile(from: Com_Octopuscommunity_PrivateProfile.with {
            $0.id = "p1"
            $0.pictureURL = "https://cdn.example.com/a1b2.jpg"
            $0.defaultAvatarIfPictureRemoved = Self.image
        }, userId: "u1")
        #expect(profile.pictureUrl == Self.imageUrl)
        #expect(profile.defaultAvatarIfPictureRemoved == .image(url: Self.imageUrl))
    }

    @Test func privateProfileWithoutDefaultKeepsItsPicture() {
        let profile = StorableCurrentUserProfile(from: Com_Octopuscommunity_PrivateProfile.with {
            $0.id = "p1"
            $0.pictureURL = "https://cdn.example.com/own.jpg"
        }, userId: "u1")
        #expect(profile.defaultAvatar == nil)
        #expect(profile.pictureUrl == URL(string: "https://cdn.example.com/own.jpg"))
    }
}
