import SwiftUI
import Isle

struct MapsScene: View {
    @State private var notificationItem: NotificationItem?
    @State private var confirmationItem: ConfirmationItem?

    enum NotificationItem: Identifiable {
        case turnLeft, arriving, rerouting, speedLimit, parking

        var id: Self { self }
    }

    enum ConfirmationItem: Identifiable {
        case endRoute, reportProblem

        var id: Self { self }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.blue.gradient)
                            .frame(width: 60, height: 60)
                        Image(systemName: "map.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Navigation Active")
                            .font(.headline)
                        Text("Arriving in 12 min · 3.2 km")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Button { notificationItem = .turnLeft } label: {
                    Label("Turn Left", systemImage: "arrow.turn.up.left")
                }
                Button { notificationItem = .arriving } label: {
                    Label("Arriving", systemImage: "mappin.and.ellipse")
                }
                Button { notificationItem = .rerouting } label: {
                    Label("Rerouting", systemImage: "arrow.triangle.swap")
                }
                Button { notificationItem = .speedLimit } label: {
                    Label("Speed Limit", systemImage: "speed.limit")
                }
                Button { notificationItem = .parking } label: {
                    Label("Parking Nearby", systemImage: "parkingsign")
                }
            } header: { Text("Notifications") }

            Section {
                Button { showConfirmation(title: "End Route?", message: "You are 3.2 km from your destination.", onConfirm: { print("Route ended") }) } label: {
                    Label("End Route Prompt", systemImage: "questionmark.circle")
                }
                Button { showConfirmation(title: "Report Problem", message: "Send a traffic report for this location?", confirmTitle: "Report", cancelTitle: "Cancel", onConfirm: { print("Reported") }) } label: {
                    Label("Report Problem", systemImage: "exclamationmark.triangle")
                }
            } header: { Text("Confirmations") }
        }
        .navigationTitle("Maps")
        .isleNotification(item: $notificationItem) { item in
            switch item {
            case .turnLeft:
                Isle.Configuration(
                    presentation: .compactWrap,
                    content: .init(
                        leadingImage: UIImage(systemName: "arrow.turn.up.left"),
                        leadingImageTintColor: .systemBlue,
                        title: "Turn left onto Main St",
                        trailingAccessory: .text("200 m")
                    )
                )
            case .arriving:
                Isle.Configuration(
                    presentation: .expanded,
                    content: .init(
                        leadingImage: UIImage(systemName: "mappin.and.ellipse"),
                        leadingImageTintColor: .systemBlue,
                        title: "Arriving at destination",
                        subtitle: "Cafe Central · 2 min",
                        trailingAccessory: .text("Stop")
                    )
                )
            case .rerouting:
                Isle.Configuration(
                    presentation: .compactPill,
                    content: .init(
                        leadingImage: UIImage(systemName: "arrow.triangle.swap"),
                        leadingImageTintColor: .systemOrange,
                        title: "Rerouting…"
                    )
                )
            case .speedLimit:
                Isle.Configuration(
                    presentation: .compactWrap,
                    content: .init(
                        leadingImage: UIImage(systemName: "speed.limit"),
                        leadingImageTintColor: .systemRed,
                        title: "Speed Limit 40",
                        trailingAccessory: .text("You: 52")
                    ),
                    autoDismissAfter: 4
                )
            case .parking:
                Isle.Configuration(
                    presentation: .expanded,
                    content: .init(
                        leadingImage: UIImage(systemName: "parkingsign"),
                        leadingImageTintColor: .systemBlue,
                        title: "Parking Nearby",
                        subtitle: "Garage · $4/hr · 2 spots",
                        trailingAccessory: .text("Reserve")
                    ),
                    autoDismissAfter: 5
                )
            }
        }
    }

    private func showConfirmation(title: String, message: String, confirmTitle: String = "OK", cancelTitle: String = "Cancel", onConfirm: @escaping () -> Void) {
        IsleNotificationCenter.shared.showConfirmation(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            onConfirm: onConfirm,
            onCancel: { print("Cancelled: \(title)") }
        )
    }
}
