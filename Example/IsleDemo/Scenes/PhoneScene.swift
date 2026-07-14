import SwiftUI
import Isle

struct PhoneScene: View {
    @State private var notificationItem: NotificationItem?

    enum NotificationItem: Identifiable {
        case incomingCall, onCall, callEnded, voicemail, faceTime

        var id: Self { self }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.green.gradient)
                            .frame(width: 60, height: 60)
                        Image(systemName: "phone.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sarah Chen")
                            .font(.headline)
                        Text("Mobile · 2 min ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Button { notificationItem = .incomingCall } label: {
                    Label("Incoming Call", systemImage: "phone.ringing")
                }
                Button { notificationItem = .onCall } label: {
                    Label("Ongoing Call", systemImage: "phone.fill")
                }
                Button { notificationItem = .callEnded } label: {
                    Label("Call Ended", systemImage: "phone.down.fill")
                }
                Button { notificationItem = .voicemail } label: {
                    Label("New Voicemail", systemImage: "waveform")
                }
                Button { notificationItem = .faceTime } label: {
                    Label("FaceTime Link", systemImage: "video.fill")
                }
            } header: { Text("Simulate") }
        }
        .navigationTitle("Phone")
        .isleNotification(item: $notificationItem) { item in
            switch item {
            case .incomingCall:
                Isle.Configuration(
                    presentation: .expanded,
                    content: .init(
                        leadingImage: UIImage(systemName: "person.crop.circle.fill"),
                        leadingImageTintColor: .systemGreen,
                        title: "Sarah Chen",
                        subtitle: "Incoming Call",
                        trailingAccessory: .image(UIImage(systemName: "phone.fill")!, tint: .systemGreen)
                    ),
                    autoDismissAfter: nil
                )
            case .onCall:
                Isle.Configuration(
                    presentation: .compactWrap,
                    content: .init(
                        leadingImage: UIImage(systemName: "phone.fill"),
                        leadingImageTintColor: .systemGreen,
                        title: "00:42",
                        trailingAccessory: .text("Sarah")
                    )
                )
            case .callEnded:
                Isle.Configuration(
                    presentation: .compactPill,
                    content: .init(
                        leadingImage: UIImage(systemName: "phone.down.fill"),
                        leadingImageTintColor: .systemRed,
                        title: "Call Ended · 12:34"
                    ),
                    autoDismissAfter: 2
                )
            case .voicemail:
                Isle.Configuration(
                    presentation: .expanded,
                    content: .init(
                        leadingImage: UIImage(systemName: "waveform"),
                        leadingImageTintColor: .systemPurple,
                        title: "New Voicemail",
                        subtitle: "From: Sarah Chen · 0:23",
                        trailingAccessory: .text("Listen")
                    ),
                    autoDismissAfter: 4
                )
            case .faceTime:
                Isle.Configuration(
                    presentation: .compactWrap,
                    content: .init(
                        leadingImage: UIImage(systemName: "video.fill"),
                        leadingImageTintColor: .systemTeal,
                        title: "FaceTime",
                        trailingAccessory: .text("Link")
                    ),
                    autoDismissAfter: 4
                )
            }
        }
    }
}
