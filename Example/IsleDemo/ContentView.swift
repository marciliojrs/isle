import SwiftUI
import Isle

struct ContentView: View {
    @State private var showCamera = false
    @State private var notificationItem: NotificationItem?

    enum NotificationItem: Identifiable {
        case airPods, silent, timer, connection, activityIndicator, customSwiftUI, confirmation, applePay

        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SceneCell(icon: "music.note", iconColor: .pink, title: "Now Playing", subtitle: "Music app — AirPods connected", scene: "Music")
                    SceneCell(icon: "phone.fill", iconColor: .green, title: "Phone", subtitle: "Incoming/ongoing calls", scene: "Phone")
                    SceneCell(icon: "timer", iconColor: .orange, title: "Timer", subtitle: "Countdown with REC indicator", scene: "Timer")
                    SceneCell(icon: "map.fill", iconColor: .blue, title: "Maps", subtitle: "Navigation prompts & alerts", scene: "Maps")
                    SceneCell(icon: "camera.fill", iconColor: .gray, title: "Camera", subtitle: "Isle camera panel demo", scene: "Camera")
                } header: {
                    Label("Scenes", systemImage: "square.stack.3d.up")
                }

                Section {
                    Button { notificationItem = .airPods } label: { DemoRow(icon: "airpodspro", color: .white, title: "AirPods Pro", subtitle: "Expanded — Connected / 82%") }
                    Button { notificationItem = .silent } label: { DemoRow(icon: "bell.slash.fill", color: .white, title: "Silent Mode", subtitle: "Compact pill — bell.slash") }
                    Button { notificationItem = .timer } label: { DemoRow(icon: "timer", color: .orange, title: "Timer 0:12", subtitle: "Compact wrap — REC trailing") }
                    Button { notificationItem = .applePay } label: { DemoRow(icon: "applepay", color: .white, title: "Apple Pay", subtitle: "Expanded — confirmation buttons") }
                    Button { notificationItem = .connection } label: { DemoRow(icon: "wifi.exclamationmark", color: .red, title: "Connection Issue", subtitle: "Preset — compact pill, red") }
                    Button { notificationItem = .activityIndicator } label: { DemoRow(icon: "arrow.triangle.2.circlepath", color: .white, title: "Downloading", subtitle: "Activity indicator + compact pill") }
                    Button { notificationItem = .customSwiftUI } label: { DemoRow(icon: "square.and.pencil", color: .purple, title: "Custom SwiftUI", subtitle: "SwiftUI ProgressView in center slot") }
                    Button { notificationItem = .confirmation } label: { DemoRow(icon: "hand.raised.fill", color: .yellow, title: "Confirmation Prompt", subtitle: "Permission-style dialog") }
                } header: {
                    Label("Individual Notifications", systemImage: "bell.badge")
                }

                Section {
                    Button { showCamera = true } label: { DemoRow(icon: "camera.viewfinder", color: .white, title: "Open Camera", subtitle: "Full camera panel from island") }
                } header: {
                    Label("Camera", systemImage: "camera")
                }
            }
            .navigationTitle("Isle Demo")
            .navigationDestination(for: String.self) { scene in
                switch scene {
                case "Music": MusicScene()
                case "Phone": PhoneScene()
                case "Timer": TimerScene()
                case "Maps": MapsScene()
                case "Camera": CameraScene()
                default: EmptyView()
                }
            }
            .isleNotification(item: $notificationItem) { item in
                let config: Isle.Configuration
                switch item {
                case .airPods:
                    config = Isle.Configuration(
                        presentation: .expanded,
                        content: .init(
                            leadingImage: UIImage(systemName: "airpodspro"),
                            leadingImageTintColor: .white,
                            title: "AirPods Pro",
                            subtitle: "Connected",
                            trailingAccessory: .text("82%")
                        )
                    )
                case .silent:
                    config = Isle.Configuration(
                        presentation: .compactPill,
                        content: .init(
                            leadingImage: UIImage(systemName: "bell.slash.fill"),
                            leadingImageTintColor: .white,
                            title: "Silent"
                        )
                    )
                case .timer:
                    config = Isle.Configuration(
                        presentation: .compactWrap,
                        content: .init(
                            leadingImage: UIImage(systemName: "timer"),
                            leadingImageTintColor: .white,
                            title: "0:12",
                            trailingAccessory: .text("REC")
                        )
                    )
                case .applePay:
                    config = Isle.Configuration(
                        presentation: .expanded,
                        content: .init(
                            leadingImage: UIImage(systemName: "apple.logo"),
                            leadingImageTintColor: .white,
                            title: "Apple Pay",
                            subtitle: "$120.00 — Coffee Shop",
                            trailingAccessory: .text("Pay")
                        )
                    )
                case .connection:
                    config = Isle.Configuration.connectionIssue(message: "No Internet Connection")
                case .activityIndicator:
                    config = Isle.Configuration(
                        presentation: .compactPill,
                        content: .init(
                            title: "Downloading…",
                            showsActivityIndicator: true
                        )
                    )
                case .customSwiftUI:
                    let center = HostingView(
                        customView: HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Syncing…").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        }
                    )
                    config = Isle.Configuration(
                        presentation: .compactPill,
                        content: .init(centerView: center),
                        autoDismissAfter: nil
                    )
                case .confirmation:
                    IsleNotificationCenter.shared.showConfirmation(
                        title: "Camera Access",
                        message: "Allow Isle to open the camera?",
                        confirmTitle: "OK",
                        cancelTitle: "Cancel",
                        onConfirm: { print("Confirmed") },
                        onCancel: { print("Cancelled") }
                    )
                    config = Isle.Configuration(
                        presentation: .expanded,
                        content: .init(title: "Placeholder"),
                        autoDismissAfter: 0.01
                    )
                }
                return config
            }
            .isleCamera(
                isPresented: $showCamera,
                configuration: Isle.CameraConfiguration(
                    permissionTitle: "Camera Access",
                    permissionMessage: "Isle needs camera access for the demo",
                    permissionConfirmTitle: "Allow",
                    permissionCancelTitle: "Not Now",
                    dismissesAfterCapture: true
                ),
                onCapture: { _ in print("Captured photo") },
                onError: { error in print("Camera error: \(error)") }
            )
        }
    }
}

struct DemoRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SceneCell: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let scene: String

    var body: some View {
        NavigationLink(value: scene) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
