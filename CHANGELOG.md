# Changelog

All notable changes to Isle will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning.

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
