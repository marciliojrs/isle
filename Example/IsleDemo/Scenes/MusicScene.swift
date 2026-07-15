import SwiftUI
import Isle

struct MusicScene: View {
    @State private var notificationItem: NotificationItem?
    @State private var nowPlaying = false

    enum NotificationItem: Identifiable {
        case airPodsConnected, airPodsDisconnected, nowPlaying

        var id: Self { self }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.pink.gradient)
                            .frame(width: 60, height: 60)
                        Image(systemName: "music.note")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Midnight City")
                            .font(.headline)
                        Text("M83 · Hurry Up, We're Dreaming")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Button { notificationItem = .airPodsConnected } label: {
                    Label("Connect AirPods", systemImage: "airpodspro")
                }
                Button { notificationItem = .airPodsDisconnected } label: {
                    Label("Disconnect AirPods", systemImage: "airpodspro.slash")
                }
                Button { notificationItem = .nowPlaying } label: {
                    Label("Show Now Playing", systemImage: "play.fill")
                }
            } header: { Text("Simulate") }
        }
        .navigationTitle("Music")
        .isleNotification(item: $notificationItem) { item in
            switch item {
            case .airPodsConnected:
                Isle.Configuration(
                    presentation: .expanded,
                    content: .init(
                        leadingImage: UIImage(systemName: "airpodspro"),
                        leadingImageTintColor: .white,
                        title: "AirPods Pro",
                        subtitle: "Connected",
                        trailingAccessory: .text("82%")
                    ),
                    autoDismissAfter: 2.5
                )
            case .airPodsDisconnected:
                Isle.Configuration(
                    presentation: .expanded,
                    content: .init(
                        leadingImage: UIImage(systemName: "airpodspro.slash"),
                        leadingImageTintColor: .systemRed,
                        title: "AirPods Pro",
                        subtitle: "Disconnected",
                        trailingAccessory: .image(UIImage(systemName: "xmark.circle.fill")!, tint: .systemRed)
                    ),
                    autoDismissAfter: 3
                )
            case .nowPlaying:
                Isle.Configuration(
                    presentation: .compactWrap,
                    content: .init(
                        leadingImage: UIImage(systemName: "music.note"),
                        leadingImageTintColor: .systemPink,
                        title: "Midnight City",
                        trailingAccessory: .text("3:42")
                    ),
                    autoDismissAfter: 4
                )
            }
        }
    }
}
