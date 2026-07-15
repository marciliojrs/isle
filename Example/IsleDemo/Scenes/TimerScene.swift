import SwiftUI
import UIKit
import Isle

struct TimerScene: View {
    @State private var notificationItem: NotificationItem?
    @State private var remainingSeconds = 12 * 60 + 34
    private let sceneTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum NotificationItem: Identifiable {
        case timerRunning, timerPaused, timerDone, stopwatch, alarm

        var id: Self { self }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.orange.gradient)
                            .frame(width: 60, height: 60)
                        Image(systemName: "timer")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedTime(remainingSeconds))
                            .font(.title.weight(.semibold))
                            .monospacedDigit()
                        Text("Pizza Timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Button { notificationItem = .timerRunning } label: {
                    Label("Timer Running", systemImage: "timer")
                }
                Button { notificationItem = .timerPaused } label: {
                    Label("Timer Paused", systemImage: "pause.fill")
                }
                Button { notificationItem = .timerDone } label: {
                    Label("Timer Finished", systemImage: "bell.fill")
                }
                Button { notificationItem = .stopwatch } label: {
                    Label("Stopwatch Running", systemImage: "stopwatch.fill")
                }
                Button { notificationItem = .alarm } label: {
                    Label("Alarm Firing", systemImage: "alarm.fill")
                }
            } header: { Text("Simulate") }
        }
        .navigationTitle("Timer")
        .onReceive(sceneTimer) { _ in
            guard remainingSeconds > 0 else { return }
            remainingSeconds -= 1
        }
        .isleNotification(item: $notificationItem) { item in
            switch item {
            case .timerRunning:
                Isle.Configuration(
                    presentation: .compactWrap,
                    content: .init(
                        trailingAccessory: .text("REC"),
                        leadingView: TimerCompactLeadingView(remainingSeconds: remainingSeconds)
                    ),
                    autoDismissAfter: nil
                )
            case .timerPaused:
                Isle.Configuration(
                    presentation: .compactPill,
                    content: .init(
                        leadingImage: UIImage(systemName: "pause.fill"),
                        leadingImageTintColor: .systemYellow,
                        title: "Paused · 8:15"
                    )
                )
            case .timerDone:
                Isle.Configuration(
                    presentation: .expanded,
                    content: .init(
                        leadingImage: UIImage(systemName: "bell.fill"),
                        leadingImageTintColor: .systemOrange,
                        title: "Timer Finished",
                        subtitle: "Pizza Timer · 12:34",
                        trailingAccessory: .text("Dismiss")
                    ),
                    autoDismissAfter: nil
                )
            case .stopwatch:
                Isle.Configuration(
                    presentation: .compactWrap,
                    content: .init(
                        leadingImage: UIImage(systemName: "stopwatch.fill"),
                        leadingImageTintColor: .systemGreen,
                        title: "01:23:45",
                        trailingAccessory: .text("Lap 3")
                    )
                )
            case .alarm:
                Isle.Configuration(
                    presentation: .expanded,
                    content: .init(
                        leadingImage: UIImage(systemName: "alarm.fill"),
                        leadingImageTintColor: .systemRed,
                        title: "Alarm",
                        subtitle: "07:00 · Wake Up",
                        trailingAccessory: .image(UIImage(systemName: "bell.badge.fill")!, tint: .systemRed)
                    ),
                    autoDismissAfter: nil
                )
            }
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

@MainActor
private final class TimerCompactLeadingView: UIStackView {

    private let imageView = UIImageView(image: UIImage(systemName: "timer"))
    private let label = UILabel()
    private var remainingSeconds: Int
    private var timer: Timer?

    init(remainingSeconds: Int) {
        self.remainingSeconds = remainingSeconds
        super.init(frame: .zero)
        configure()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        timer?.invalidate()
    }

    private func configure() {
        axis = .horizontal
        alignment = .center
        spacing = 7
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        imageView.tintColor = .systemOrange
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor)
        ])

        label.textColor = .white
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        updateLabel()

        addArrangedSubview(imageView)
        addArrangedSubview(label)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.remainingSeconds > 0 else { return }
                self.remainingSeconds -= 1
                self.updateLabel()
            }
        }
    }

    private func updateLabel() {
        label.text = String(format: "%d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }
}
