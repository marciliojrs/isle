# Changelog

All notable changes to Isle will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning.

## 1.2.0

### Added

- `Configuration.hidesStatusBar` (default `true`). Pass `false` to keep the time and battery visible beside a notification that stays up.

### Changed

- On screens without a top cutout (iPhone SE, iPad, landscape, foldables with a vertical bar), compact notifications float as a snug capsule instead of a full-width bar, centred in the safe area so a side strip stays clear.
- `Isle.hasTopCutout(topSafeAreaInset:)` and `Isle.compactNotificationBottom(topSafeAreaInset:hidesStatusBar:)`, so an app that keeps a compact notification up can keep its content clear of it on a flat top.
- On a flat top that keeps its status bar (`hidesStatusBar: false`), compact notifications float just below it.
- The status bar hides only when it sits at the top of the screen; with a zero top inset it is in a side strip (or hidden by the system), and hiding it would only lose the time.

## 1.1.0

### Added

- Camera capture panel via `IsleCameraCenter` with permission confirmation flow and SwiftUI binding support.
- Confirmation prompts with OK and Cancel actions through `showConfirmation`.
- Example app demonstrating all features across five demo scenes (Music, Phone, Timer, Maps, Camera).
- `IsleMarqueeView` for auto-scrolling text in compact notification slots.
- `showsActivityIndicator` option on `Content` for inline progress indicators.
- Comprehensive test suite covering notification presentation, dismissal, camera, and confirmation flows.

### Changed

- Improved notification presentation and dismissal animations.
- Better device geometry detection for Dynamic Island, notch, and flat-top devices.
- Enhanced SwiftUI `isleNotification` modifier reliability.
- Status bar now hides while camera panel is visible.

### Fixed

- Notification replacement timing when rapid present/dismiss cycles occur.
- Swipe-to-dismiss gesture recognition edge cases.
- Haptic feedback consistency across presentation types.

## 1.0.0

### Added

- Initial Isle package.
- Open-source documentation polish, contribution guidance, and project health templates.
- Expanded, compact pill, and compact wrap notification presentations.
- UIKit presentation through `IsleNotificationCenter`.
- SwiftUI presentation through `View.isleNotification(...)`.
- Custom content slots with `UIView` and `HostingView`.
- Connection issue preset.
