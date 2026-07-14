import SwiftUI
import Isle

struct CameraScene: View {
    @State private var showCamera = false
    @State private var notificationItem: NotificationItem?
    @State private var lastCapturedImage: UIImage?

    enum NotificationItem: Identifiable {
        case cameraReady, photoCaptured

        var id: Self { self }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.black)
                            .frame(width: 60, height: 60)
                        Image(systemName: "camera.viewfinder")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Isle Camera Panel")
                            .font(.headline)
                        Text("Opens from Dynamic Island")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Button { showCamera = true } label: {
                    Label("Open Camera", systemImage: "camera.fill")
                }
            } header: { Text("Actions") }

            if let image = lastCapturedImage {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                } header: { Text("Last Capture") }
            }

            Section {
                Button { notificationItem = .cameraReady } label: {
                    Label("Camera Ready Notification", systemImage: "camera.badge.ellipsis")
                }
                Button { notificationItem = .photoCaptured } label: {
                    Label("Photo Captured Notification", systemImage: "checkmark.circle")
                }
            } header: { Text("Simulate") }
        }
        .navigationTitle("Camera Demo")
        .isleCamera(
            isPresented: $showCamera,
            configuration: Isle.CameraConfiguration(
                permissionTitle: "Camera Access",
                permissionMessage: "Isle needs camera access to demonstrate the Dynamic Island camera panel.",
                permissionConfirmTitle: "Allow",
                permissionCancelTitle: "Not Now",
                allowsSwipeToDismiss: false,
                dismissesAfterCapture: true,
                haptic: .soft,
                captureHaptic: .medium
            ),
            onCapture: { image in
                lastCapturedImage = image
                notificationItem = .photoCaptured
            },
            onError: { error in
                print("Camera error: \(error)")
            }
        )
        .isleNotification(item: $notificationItem) { item in
            switch item {
            case .cameraReady:
                Isle.Configuration(
                    presentation: .compactPill,
                    content: .init(
                        leadingImage: UIImage(systemName: "camera.fill"),
                        leadingImageTintColor: .white,
                        title: "Camera Ready"
                    ),
                    autoDismissAfter: 2
                )
            case .photoCaptured:
                Isle.Configuration(
                    presentation: .compactPill,
                    content: .init(
                        leadingImage: UIImage(systemName: "checkmark.circle.fill"),
                        leadingImageTintColor: .systemGreen,
                        title: "Photo Captured"
                    ),
                    autoDismissAfter: 2
                )
            }
        }
    }
}
