#if os(iOS)
import UIKit

/// Namespace for the in-app, Dynamic-Island-styled notification helper.
///
/// This is a *fake* island overlay drawn on top of the app — not an ActivityKit
/// Live Activity. It is foreground-only and needs no widget extension or entitlements.
public enum Isle {

    /// How `IsleNotificationCenter.show` handles a new notification when another one
    /// is already visible.
    public enum PresentationBehavior {
        /// Dismiss the current notification and show the new one immediately.
        case replace
        /// Keep the current notification visible and show the new one after it dismisses.
        case enqueue
        /// If the visible notification matches the new one, replay attention animation
        /// instead of replacing it. Otherwise behaves like `.replace`.
        case bounceIfSame
    }

    /// The visual form a notification takes.
    public enum Presentation {
        /// Big card that drops from the island: leading image, title, subtitle, trailing accessory.
        case expanded
        /// Compact content hugging the physical island: leading on the left, trailing on the right.
        case compactWrap
        /// A single centered pill just below the island: leading image + title.
        case compactPill
    }

    /// A trailing accessory shown on the right of `.expanded` / `.compactWrap`.
    public enum Accessory {
        case image(UIImage, tint: UIColor?)
        case text(String)
    }

    /// Content rendered inside a notification. Which fields are used depends on
    /// the `Presentation` (see `Configuration`).
    public struct Content {
        public var leadingImage: UIImage?
        public var leadingImageTintColor: UIColor?
        public var title: String?
        public var subtitle: String?
        public var trailingAccessory: Accessory?
        /// When true, a leading indeterminate activity indicator is shown as the
        /// leading-most element to signal ongoing work. Independent of `leadingImage`.
        public var showsActivityIndicator: Bool

        /// Custom views that override the built-in content for a slot when set. Pass any
        /// `UIView`, or a SwiftUI view wrapped in `HostingView(customView:)`.
        /// - `leadingView`: replaces the leading image/indicator (`.expanded`, `.compactWrap`).
        /// - `centerView`: replaces the title/subtitle block (`.expanded`) or the centered
        ///   content (`.compactPill`).
        /// - `trailingView`: replaces the trailing accessory (`.expanded`, `.compactWrap`).
        public var leadingView: UIView?
        public var centerView: UIView?
        public var trailingView: UIView?

        public init(
            leadingImage: UIImage? = nil,
            leadingImageTintColor: UIColor? = nil,
            title: String? = nil,
            subtitle: String? = nil,
            trailingAccessory: Accessory? = nil,
            showsActivityIndicator: Bool = false,
            leadingView: UIView? = nil,
            centerView: UIView? = nil,
            trailingView: UIView? = nil
        ) {
            self.leadingImage = leadingImage
            self.leadingImageTintColor = leadingImageTintColor
            self.title = title
            self.subtitle = subtitle
            self.trailingAccessory = trailingAccessory
            self.showsActivityIndicator = showsActivityIndicator
            self.leadingView = leadingView
            self.centerView = centerView
            self.trailingView = trailingView
        }
    }

    /// Everything needed to present one notification.
    ///
    /// Field usage per presentation:
    /// - `.expanded`: all fields.
    /// - `.compactWrap`: `leadingImage` + `title` (left), `trailingAccessory` (right). `subtitle` ignored.
    /// - `.compactPill`: `leadingImage` + `title` (centered). `subtitle` + `trailingAccessory` ignored.
    public struct Configuration {
        /// Optional stable identity used to detect repeated notifications. Set this for
        /// repeatable states such as `"network-error"` when using `.bounceIfSame`.
        public var id: String?
        public var presentation: Presentation
        public var content: Content
        /// Seconds before auto-dismiss. `nil` keeps it until dismissed programmatically.
        public var autoDismissAfter: TimeInterval?
        public var allowsSwipeToDismiss: Bool
        /// Impact haptic played when the notification is presented. `nil` plays no haptic.
        public var haptic: UIImpactFeedbackGenerator.FeedbackStyle?

        public init(
            id: String? = nil,
            presentation: Presentation,
            content: Content,
            autoDismissAfter: TimeInterval? = 3,
            allowsSwipeToDismiss: Bool = true,
            haptic: UIImpactFeedbackGenerator.FeedbackStyle? = .soft
        ) {
            self.id = id
            self.presentation = presentation
            self.content = content
            self.autoDismissAfter = autoDismissAfter
            self.allowsSwipeToDismiss = allowsSwipeToDismiss
            self.haptic = haptic
        }
    }

    /// Everything needed to present Isle's camera overlay.
    public struct CameraConfiguration: Sendable {
        public var permissionTitle: String
        public var permissionMessage: String?
        public var permissionConfirmTitle: String
        public var permissionCancelTitle: String
        public var allowsSwipeToDismiss: Bool
        public var dismissesAfterCapture: Bool
        /// Impact haptic played when the camera panel is presented. `nil` plays no haptic.
        public var haptic: UIImpactFeedbackGenerator.FeedbackStyle?
        /// Impact haptic played when the shutter button is tapped. `nil` plays no haptic.
        public var captureHaptic: UIImpactFeedbackGenerator.FeedbackStyle?

        public init(
            permissionTitle: String = "Camera Access",
            permissionMessage: String? = "Allow Isle to open the camera?",
            permissionConfirmTitle: String = "OK",
            permissionCancelTitle: String = "Cancel",
            allowsSwipeToDismiss: Bool = true,
            dismissesAfterCapture: Bool = true,
            haptic: UIImpactFeedbackGenerator.FeedbackStyle? = .soft,
            captureHaptic: UIImpactFeedbackGenerator.FeedbackStyle? = .medium
        ) {
            self.permissionTitle = permissionTitle
            self.permissionMessage = permissionMessage
            self.permissionConfirmTitle = permissionConfirmTitle
            self.permissionCancelTitle = permissionCancelTitle
            self.allowsSwipeToDismiss = allowsSwipeToDismiss
            self.dismissesAfterCapture = dismissesAfterCapture
            self.haptic = haptic
            self.captureHaptic = captureHaptic
        }
    }
}

// MARK: - Presets

extension Isle.Configuration {
    /// Pre-configured compact notification for connectivity loss — a wifi-exclamation
    /// glyph tinted critical red. Callers supply the localized message so the
    /// component stays string-table-agnostic (mirrors `Toast.connectionIssue`).
    public static func connectionIssue(message: String) -> Self {
        Isle.Configuration(
            presentation: .compactPill,
            content: Isle.Content(
                leadingImage: UIImage(systemName: "wifi.exclamationmark"),
                leadingImageTintColor: IsleColors.critical,
                title: message
            )
        )
    }
}

// MARK: - Metrics

extension Isle {
    /// Geometry constants and device detection for positioning the fake island.
    enum Metrics {
        /// Physical Dynamic Island footprint (portrait), approximate.
        static let islandWidth: CGFloat = 126
        static let islandHeight: CGFloat = 37
        /// Distance from the top of the screen to the top of the physical island.
        static let islandTopInset: CGFloat = 11

        /// Notch (iPhone X–14 non-Pro) approximate footprint. The notch is flush with
        /// the screen's top edge, wider and slightly shorter than the island.
        static let notchWidth: CGFloat = 165
        static let notchHeight: CGFloat = 33
        static let notchTopInset: CGFloat = 0

        /// Island devices (14 Pro / 15 / 16-class) report a top safe-area inset of
        /// ~59pt; notched non-island devices report ~44–47pt; flat-top devices ~20pt.
        /// A threshold of 51 cleanly separates island from notch/flat.
        static let islandInsetThreshold: CGFloat = 51

        static let expandedCornerRadius: CGFloat = 28
        static let compactCornerRadius: CGFloat = islandHeight / 2  // 18.5
        /// Matches the modern iPhone display corner radius closely enough for an
        /// overlay that attaches to the device edge.
        static let cameraCornerRadius: CGFloat = 39
        /// Physical screen corner radius so full-width compact notifications
        /// blend seamlessly with the device display on notch / flat-top devices.
        /// Derived from the top safe-area inset which encodes the device class.
        static func screenCornerRadius(topSafeAreaInset: CGFloat) -> CGFloat {
            switch cutoutKind(topSafeAreaInset: topSafeAreaInset) {
            case .dynamicIsland: return 47
            case .notch:         return 47
            case .none:          return 0 
            }
        }
        static func compactWrapEdgeInset(topSafeAreaInset: CGFloat) -> CGFloat {
            max(sideInset, screenCornerRadius(topSafeAreaInset: topSafeAreaInset) - compactCornerRadius)
        }
        static let compactWrapTextMaxWidth: CGFloat = 90
        static let compactPillTextMaxWidth: CGFloat = 120
        static let compactTrailingTextMaxWidth: CGFloat = 64
        static let sideInset: CGFloat = 12
        static let contentInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

        /// True when the presenting environment has a Dynamic Island (vs a notch
        /// or flat top), inferred from the top safe-area inset.
        static func hasDynamicIsland(topSafeAreaInset: CGFloat) -> Bool {
            topSafeAreaInset >= islandInsetThreshold
        }

        /// Notch devices report a top inset at or above this (but below the island
        /// threshold); flat-top devices (SE, iPad) report less and have neither cutout.
        static let notchInsetThreshold: CGFloat = 35

        /// The physical top cutout of the presenting device.
        enum CutoutKind { case dynamicIsland, notch, none }

        static func cutoutKind(topSafeAreaInset: CGFloat) -> CutoutKind {
            if topSafeAreaInset >= islandInsetThreshold { return .dynamicIsland }
            if topSafeAreaInset >= notchInsetThreshold { return .notch }
            return .none
        }

        /// Top offset of the notification shape from the window's top edge: the island
        /// floats ~11pt down and the notch is flush with the top (0). Flat-top devices
        /// (no cutout) float at the same inset as the island so the notification reads as
        /// a floating pill near the top rather than pinned to the edge.
        static func shapeTopOffset(topSafeAreaInset: CGFloat) -> CGFloat {
            switch cutoutKind(topSafeAreaInset: topSafeAreaInset) {
            case .dynamicIsland: return islandTopInset
            case .notch: return notchTopInset
            case .none: return islandTopInset
            }
        }

        /// Width of the physical cutout to clear when content flanks it (flat-top uses a
        /// small separation since there is no cutout).
        static func cutoutWidth(topSafeAreaInset: CGFloat) -> CGFloat {
            switch cutoutKind(topSafeAreaInset: topSafeAreaInset) {
            case .dynamicIsland: return islandWidth
            case .notch: return notchWidth
            case .none: return 8
            }
        }

        /// Height of the compact one-liner so the bar coincides with the cutout.
        static func cutoutHeight(topSafeAreaInset: CGFloat) -> CGFloat {
            switch cutoutKind(topSafeAreaInset: topSafeAreaInset) {
            case .dynamicIsland: return islandHeight
            case .notch, .none: return notchHeight
            }
        }

        static func cameraHeight(for windowHeight: CGFloat) -> CGFloat {
            max(320, windowHeight * 0.5)
        }
    }
}
#endif
