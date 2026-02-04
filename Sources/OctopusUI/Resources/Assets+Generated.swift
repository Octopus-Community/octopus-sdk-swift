// Generated code. Do not edit directly.

import Foundation
import SwiftUI
import UIKit

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private let resourceBundle: Bundle = {
    let bundleName = "OctopusUI"

    let candidates = [
        Bundle(for: BundleModuleLocator.self),
        Bundle.main,
    ]

    for candidate in candidates {
        if let url = candidate.url(forResource: bundleName, withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
    }

    fatalError("Cannot find resource bundle named \(bundleName)")
}()
#endif

// MARK: - Generated Resource Base Types -
/// A color resource.
struct GenColorResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog color resource name.
    fileprivate let name: Swift.String

    /// An asset catalog color resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize a `GenColorResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

/// An image resource.
struct GenImageResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog image resource name.
    fileprivate let name: Swift.String

    /// An asset catalog image resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize an `GenImageResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

// MARK: - UI types extensions -
extension UIKit.UIColor {

    /// Initialize a `UIColor` with a color resource.
    convenience init(res resource: GenColorResource) {
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
    }

}

extension SwiftUI.Color {

    /// Initialize a `Color` with a color resource.
    init(res resource: GenColorResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}

extension UIKit.UIImage {

    /// Initialize a `UIImage` with an image resource.
    convenience init(res resource: GenImageResource) {
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
    }

}

extension SwiftUI.Image {

    /// Initialize an `Image` with an image resource.
    init(res resource: GenImageResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}

// MARK: - Color Symbols -

extension GenColorResource {
    enum Theme {
        static let alertLowContrast = GenColorResource(name: "Theme/alertLowContrast", bundle: resourceBundle)
        static let danger200 = GenColorResource(name: "Theme/danger200", bundle: resourceBundle)
        static let gray100 = GenColorResource(name: "Theme/gray100", bundle: resourceBundle)
        static let gray200 = GenColorResource(name: "Theme/gray200", bundle: resourceBundle)
        static let gray300 = GenColorResource(name: "Theme/gray300", bundle: resourceBundle)
        static let gray500 = GenColorResource(name: "Theme/gray500", bundle: resourceBundle)
        static let gray700 = GenColorResource(name: "Theme/gray700", bundle: resourceBundle)
        static let gray800 = GenColorResource(name: "Theme/gray800", bundle: resourceBundle)
        static let gray900 = GenColorResource(name: "Theme/gray900", bundle: resourceBundle)
        static let hover = GenColorResource(name: "Theme/hover", bundle: resourceBundle)
        static let link = GenColorResource(name: "Theme/link", bundle: resourceBundle)
        enum Primary {
            static let highContrast = GenColorResource(name: "Theme/Primary/highContrast", bundle: resourceBundle)
            static let lowContrast = GenColorResource(name: "Theme/Primary/lowContrast", bundle: resourceBundle)
            static let main = GenColorResource(name: "Theme/Primary/main", bundle: resourceBundle)
        }
    }
}

// MARK: - Image Symbols -

extension GenImageResource {
    static let addMedia = GenImageResource(name: "addMedia", bundle: resourceBundle)
    static let bell = GenImageResource(name: "bell", bundle: resourceBundle)
    static let congrats = GenImageResource(name: "congrats", bundle: resourceBundle)
    static let contentNotAvailable = GenImageResource(name: "contentNotAvailable", bundle: resourceBundle)
    static let createPost = GenImageResource(name: "createPost", bundle: resourceBundle)
    static let editPicture = GenImageResource(name: "editPicture", bundle: resourceBundle)
    static let more = GenImageResource(name: "more", bundle: resourceBundle)
    static let noCurrentUserPost = GenImageResource(name: "noCurrentUserPost", bundle: resourceBundle)
    static let noPosts = GenImageResource(name: "noPosts", bundle: resourceBundle)
    static let poll = GenImageResource(name: "poll", bundle: resourceBundle)
    static let poweredByOctopus = GenImageResource(name: "poweredByOctopus", bundle: resourceBundle)
    static let search = GenImageResource(name: "search", bundle: resourceBundle)
    static let send = GenImageResource(name: "send", bundle: resourceBundle)
    static let trash = GenImageResource(name: "trash", bundle: resourceBundle)
    enum AggregatedInfo {
        static let comment = GenImageResource(name: "AggregatedInfo/comment", bundle: resourceBundle)
        static let like = GenImageResource(name: "AggregatedInfo/like", bundle: resourceBundle)
        static let likeActivated = GenImageResource(name: "AggregatedInfo/likeActivated", bundle: resourceBundle)
        static let view = GenImageResource(name: "AggregatedInfo/view", bundle: resourceBundle)
    }
    enum CheckBox {
        static let off = GenImageResource(name: "CheckBox/off", bundle: resourceBundle)
        static let on = GenImageResource(name: "CheckBox/on", bundle: resourceBundle)
    }
    enum Gamification {
        static let badge = GenImageResource(name: "Gamification/badge", bundle: resourceBundle)
        static let rulesHeader = GenImageResource(name: "Gamification/rulesHeader", bundle: resourceBundle)
    }
    enum RadioButton {
        static let off = GenImageResource(name: "RadioButton/off", bundle: resourceBundle)
        static let on = GenImageResource(name: "RadioButton/on", bundle: resourceBundle)
    }
    enum Settings {
        static let account = GenImageResource(name: "Settings/account", bundle: resourceBundle)
        static let help = GenImageResource(name: "Settings/help", bundle: resourceBundle)
        static let info = GenImageResource(name: "Settings/info", bundle: resourceBundle)
        static let logout = GenImageResource(name: "Settings/logout", bundle: resourceBundle)
        static let warning = GenImageResource(name: "Settings/warning", bundle: resourceBundle)
    }
    enum Theme {
        static let logo = GenImageResource(name: "Theme/logo", bundle: resourceBundle)
    }
    enum Toggle {
        static let off = GenImageResource(name: "Toggle/off", bundle: resourceBundle)
        static let on = GenImageResource(name: "Toggle/on", bundle: resourceBundle)
    }
    enum Video {
        static let muted = GenImageResource(name: "Video/muted", bundle: resourceBundle)
        static let notMuted = GenImageResource(name: "Video/notMuted", bundle: resourceBundle)
        static let pause = GenImageResource(name: "Video/pause", bundle: resourceBundle)
        static let play = GenImageResource(name: "Video/play", bundle: resourceBundle)
        static let replay = GenImageResource(name: "Video/replay", bundle: resourceBundle)
    }
}

// MARK: - Color Symbol Extensions -

extension SwiftUI.Color {
    enum Gen {
        enum Theme {
            static var alertLowContrast: SwiftUI.Color { .init(res: .Theme.alertLowContrast) }
            static var danger200: SwiftUI.Color { .init(res: .Theme.danger200) }
            static var gray100: SwiftUI.Color { .init(res: .Theme.gray100) }
            static var gray200: SwiftUI.Color { .init(res: .Theme.gray200) }
            static var gray300: SwiftUI.Color { .init(res: .Theme.gray300) }
            static var gray500: SwiftUI.Color { .init(res: .Theme.gray500) }
            static var gray700: SwiftUI.Color { .init(res: .Theme.gray700) }
            static var gray800: SwiftUI.Color { .init(res: .Theme.gray800) }
            static var gray900: SwiftUI.Color { .init(res: .Theme.gray900) }
            static var hover: SwiftUI.Color { .init(res: .Theme.hover) }
            static var link: SwiftUI.Color { .init(res: .Theme.link) }
            enum Primary {
                static var highContrast: SwiftUI.Color { .init(res: .Theme.Primary.highContrast) }
                static var lowContrast: SwiftUI.Color { .init(res: .Theme.Primary.lowContrast) }
                static var main: SwiftUI.Color { .init(res: .Theme.Primary.main) }
            }
        }
    }
}

extension UIKit.UIColor {
    enum Gen {
        enum Theme {
            static var alertLowContrast: UIKit.UIColor { .init(res: .Theme.alertLowContrast) }
            static var danger200: UIKit.UIColor { .init(res: .Theme.danger200) }
            static var gray100: UIKit.UIColor { .init(res: .Theme.gray100) }
            static var gray200: UIKit.UIColor { .init(res: .Theme.gray200) }
            static var gray300: UIKit.UIColor { .init(res: .Theme.gray300) }
            static var gray500: UIKit.UIColor { .init(res: .Theme.gray500) }
            static var gray700: UIKit.UIColor { .init(res: .Theme.gray700) }
            static var gray800: UIKit.UIColor { .init(res: .Theme.gray800) }
            static var gray900: UIKit.UIColor { .init(res: .Theme.gray900) }
            static var hover: UIKit.UIColor { .init(res: .Theme.hover) }
            static var link: UIKit.UIColor { .init(res: .Theme.link) }
            enum Primary {
                static var highContrast: UIKit.UIColor { .init(res: .Theme.Primary.highContrast) }
                static var lowContrast: UIKit.UIColor { .init(res: .Theme.Primary.lowContrast) }
                static var main: UIKit.UIColor { .init(res: .Theme.Primary.main) }
            }
        }
    }
}

// MARK: - Image Symbol Extensions -

extension UIKit.UIImage {
    enum Gen {
        static var addMedia: UIKit.UIImage { .init(res: .addMedia) }
        static var bell: UIKit.UIImage { .init(res: .bell) }
        static var congrats: UIKit.UIImage { .init(res: .congrats) }
        static var contentNotAvailable: UIKit.UIImage { .init(res: .contentNotAvailable) }
        static var createPost: UIKit.UIImage { .init(res: .createPost) }
        static var editPicture: UIKit.UIImage { .init(res: .editPicture) }
        static var more: UIKit.UIImage { .init(res: .more) }
        static var noCurrentUserPost: UIKit.UIImage { .init(res: .noCurrentUserPost) }
        static var noPosts: UIKit.UIImage { .init(res: .noPosts) }
        static var poll: UIKit.UIImage { .init(res: .poll) }
        static var poweredByOctopus: UIKit.UIImage { .init(res: .poweredByOctopus) }
        static var search: UIKit.UIImage { .init(res: .search) }
        static var send: UIKit.UIImage { .init(res: .send) }
        static var trash: UIKit.UIImage { .init(res: .trash) }
        enum AggregatedInfo {
            static var comment: UIKit.UIImage { .init(res: .AggregatedInfo.comment) }
            static var like: UIKit.UIImage { .init(res: .AggregatedInfo.like) }
            static var likeActivated: UIKit.UIImage { .init(res: .AggregatedInfo.likeActivated) }
            static var view: UIKit.UIImage { .init(res: .AggregatedInfo.view) }
        }
        enum CheckBox {
            static var off: UIKit.UIImage { .init(res: .CheckBox.off) }
            static var on: UIKit.UIImage { .init(res: .CheckBox.on) }
        }
        enum Gamification {
            static var badge: UIKit.UIImage { .init(res: .Gamification.badge) }
            static var rulesHeader: UIKit.UIImage { .init(res: .Gamification.rulesHeader) }
        }
        enum RadioButton {
            static var off: UIKit.UIImage { .init(res: .RadioButton.off) }
            static var on: UIKit.UIImage { .init(res: .RadioButton.on) }
        }
        enum Settings {
            static var account: UIKit.UIImage { .init(res: .Settings.account) }
            static var help: UIKit.UIImage { .init(res: .Settings.help) }
            static var info: UIKit.UIImage { .init(res: .Settings.info) }
            static var logout: UIKit.UIImage { .init(res: .Settings.logout) }
            static var warning: UIKit.UIImage { .init(res: .Settings.warning) }
        }
        enum Theme {
            static var logo: UIKit.UIImage { .init(res: .Theme.logo) }
        }
        enum Toggle {
            static var off: UIKit.UIImage { .init(res: .Toggle.off) }
            static var on: UIKit.UIImage { .init(res: .Toggle.on) }
        }
        enum Video {
            static var muted: UIKit.UIImage { .init(res: .Video.muted) }
            static var notMuted: UIKit.UIImage { .init(res: .Video.notMuted) }
            static var pause: UIKit.UIImage { .init(res: .Video.pause) }
            static var play: UIKit.UIImage { .init(res: .Video.play) }
            static var replay: UIKit.UIImage { .init(res: .Video.replay) }
        }
    }
}
