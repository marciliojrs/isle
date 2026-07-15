# Isle Demo

An example app showcasing all Isle features — notifications, confirmations, and camera panels — in real-world scenarios.

## Setup

```bash
cd Example
tuist generate --no-open
open IsleDemo.xcworkspace
```

Then select an iOS 17+ simulator and run.

## Features Demonstrated

| Demo | Isle APIs Tested |
|------|-----------------|
| **Music Scene** | `.expanded` (AirPods connect/disconnect), `.compactWrap` (now playing) |
| **Phone Scene** | `.expanded` with `autoDismissAfter: nil`, `.compactWrap`, `.compactPill` (call ended), trailing `.image`/`.text` |
| **Timer Scene** | `.compactWrap` + REC label, `.compactPill` (pause), `.expanded` (alarm), stopwatch wrap |
| **Maps Scene** | Turn-by-turn `.compactWrap`, arrival `.expanded`, rerouting `.compactPill`, `showConfirmation()` dialog |
| **Camera Scene** | `.isleCamera(isPresented:)` with permission flow, configurable haptics/swipe, captured image preview |
| **AirPods** | `.expanded` — leadingImage + title + subtitle + trailing text |
| **Silent** | `.compactPill` — single icon + title |
| **Timer 0:12** | `.compactWrap` — leading image + title + trailing accessory |
| **Apple Pay** | `.expanded` — confirmation-like layout with Pay text |
| **Connection Issue** | `.connectionIssue(message:)` preset |
| **Downloading** | `showsActivityIndicator: true` on `.compactPill` |
| **Custom SwiftUI** | `HostingView` with SwiftUI `ProgressView` in center slot |
| **Confirmation Prompt** | `showConfirmation(title:message:onConfirm:onCancel:)` |
| **Open Camera** | `.isleCamera()` modifier with capture callback |
