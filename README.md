# Isle

In-app notifications styled like the iPhone Dynamic Island.

Isle draws a fake, in-app Dynamic-Island-styled notification overlay on top of your app's own content. It is **not** an ActivityKit Live Activity — it needs no widget extension, no entitlements, and works purely in the foreground, on any iPhone (island, notch, or flat-top).

> **Not affiliated with Apple.** "Dynamic Island" is a trademark of Apple Inc. Isle merely mimics its visual language for in-app notifications; it does not use, extend, or depend on ActivityKit or any private API.

## Features

- Three presentations: `expanded`, `compactWrap`, and `compactPill`
- Device-aware geometry — automatically adapts to island, notch, or flat-top devices
- Grow-from-the-island animation on present and dismiss
- Status bar is hidden while a notification is presented, matching the system's own behavior
- Auto-dismiss on a timer, swipe-to-dismiss, or programmatic dismissal via a returned token
- Fully custom leading/center/trailing slots — drop in any `UIView`, or a SwiftUI view via `HostingView`
- No third-party dependencies

## Screenshots

| Expanded | Compact Pill | Compact Wrap |
|:---:|:---:|:---:|
| <img src="Screenshots/expanded.png" width="240" alt="Expanded"> | <img src="Screenshots/compact-pill.png" width="240" alt="Compact Pill"> | <img src="Screenshots/compact-wrap.png" width="240" alt="Compact Wrap"> |

## Requirements

- iOS 15.0+
- Swift 5.9+

## Installation

### Swift Package Manager

In Xcode: **File ▸ Add Package Dependencies…** and enter:

```
https://github.com/marciliojrs/isle.git
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/marciliojrs/isle.git", from: "0.1.0")
]
```

## Usage

### Expanded

An AirPods-style connect banner:

```swift
import Isle

IsleNotificationCenter.shared.show(
    Isle.Configuration(
        presentation: .expanded,
        content: Isle.Content(
            leadingImage: UIImage(systemName: "airpodspro"),
            leadingImageTintColor: .white,
            title: "AirPods Pro",
            subtitle: "Connected",
            trailingAccessory: .text("82%")
        )
    )
)
```

### Compact Pill

A Silent-mode toggle, auto-dismissed after 2 seconds:

```swift
IsleNotificationCenter.shared.show(
    Isle.Configuration(
        presentation: .compactPill,
        content: Isle.Content(
            leadingImage: UIImage(systemName: "bell.slash.fill"),
            leadingImageTintColor: .white,
            title: "Silent"
        ),
        autoDismissAfter: 2
    )
)
```

### Compact Wrap

Leading content on the left, trailing on the right — flanking the physical island/notch. Kept up indefinitely until dismissed:

```swift
IsleNotificationCenter.shared.show(
    Isle.Configuration(
        presentation: .compactWrap,
        content: Isle.Content(
            leadingImage: UIImage(systemName: "timer"),
            leadingImageTintColor: .white,
            title: "0:12",
            trailingAccessory: .text("REC")
        ),
        autoDismissAfter: nil
    )
)
```

### Connection issue preset

A ready-made compact pill for connectivity loss — a wifi-exclamation glyph tinted critical red. You supply the localized message:

```swift
IsleNotificationCenter.shared.show(.connectionIssue(message: "You are offline"))
```

### Custom SwiftUI content

Any slot (`leadingView`, `centerView`, `trailingView`) accepts a plain `UIView`, or a SwiftUI view wrapped in the module's `HostingView`:

```swift
let center = HostingView(
    customView: HStack(spacing: 8) {
        ProgressView().tint(.white)
        Text("Downloading…")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
    }
)

IsleNotificationCenter.shared.show(
    Isle.Configuration(
        presentation: .compactPill,
        content: Isle.Content(centerView: center)
    )
)
```

### Dismissal

`show(_:)` returns an `IsleToken` you can use to dismiss *that specific* notification later (a no-op if it has already been replaced or dismissed):

```swift
let token = IsleNotificationCenter.shared.show(.connectionIssue(message: "You are offline"))
// ...
token.dismiss()
```

Or dismiss whatever is currently visible:

```swift
IsleNotificationCenter.shared.dismiss()
```

Notifications also auto-dismiss after `Configuration.autoDismissAfter` seconds (default 3, `nil` to keep until dismissed) and support swipe-up-to-dismiss when `allowsSwipeToDismiss` is `true` (the default).

## SwiftUI

For SwiftUI apps, `View.isleNotification(...)` presents a notification declaratively, mirroring `alert`/`sheet`. Requires iOS 15.0+.

### `isPresented:` binding

```swift
struct ContentView: View {
    @State private var showConnected = false
    var body: some View {
        Button("Connect AirPods") { showConnected = true }
            .isleNotification(isPresented: $showConnected,
                Isle.Configuration(
                    presentation: .expanded,
                    content: .init(
                        leadingImage: UIImage(systemName: "airpodspro"),
                        leadingImageTintColor: .white,
                        title: "AirPods Pro",
                        subtitle: "Connected",
                        trailingAccessory: .text("82%"))))
    }
}
```

Setting `showConnected = true` presents the notification; setting it back to `false` dismisses it. If the notification dismisses itself instead — auto-dismiss timer, swipe, or being replaced by another notification — the binding is reset to `false` automatically, so your state always reflects what's on screen.

### `item:` binding

Present a notification built from an optional value, e.g. driving it off a view model's state:

```swift
struct ConnectionAlert: Identifiable {
    let id = UUID()
    let message: String
}

struct ContentView: View {
    @State private var connectionAlert: ConnectionAlert?
    var body: some View {
        Text("Status")
            .isleNotification(item: $connectionAlert) { alert in
                .connectionIssue(message: alert.message)
            }
    }
}
```

Setting `connectionAlert` to a non-`nil` value presents the notification; `connectionAlert` is reset to `nil` automatically once the notification dismisses — whether by your own code or on its own.

## License

Isle is released under the MIT license. See [LICENSE](LICENSE) for details.
