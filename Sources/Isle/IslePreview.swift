#if os(iOS)
#if DEBUG
import UIKit
import SwiftUI

/// A lightweight social-feed mock used as a backdrop for previews and README
/// screenshots, so the notification is judged over realistic app content instead
/// of flat grey. It is a real `List`: tapping a row presents an Isle notification
/// via the package's own `.isleNotification(item:)` modifier. Self-contained —
/// owns its selection state and starts with no notification shown.
@available(iOS 15.0, *)
struct DemoFeedView: View {
    fileprivate struct Post: Identifiable {
        let id = UUID(); let name: String; let handle: String; let body: String; let color: Color
    }
    private let posts: [Post] = [
        .init(name: "Sarah Chen", handle: "@sarahc", body: "Just shipped a huge update 🚀 so proud of the team", color: .blue),
        .init(name: "Dev Weekly", handle: "@devweekly", body: "This week: Swift concurrency, SwiftUI tips, and more", color: .purple),
        .init(name: "Maya Patel", handle: "@mayap", body: "Coffee + code = perfect Sunday morning ☕️", color: .orange),
        .init(name: "TechCrunch", handle: "@techcrunch", body: "Apple announces new accessibility features for iOS", color: .green),
        .init(name: "Alex Rivera", handle: "@arivera", body: "Anyone else obsessed with the Dynamic Island? 😍", color: .pink),
        .init(name: "Jordan Lee", handle: "@jlee", body: "New post: building delightful iOS animations", color: .teal),
    ]
    @State private var tapped: Post?

    var body: some View {
        List {
            ForEach(posts) { post in
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(post.color).frame(width: 44, height: 44)
                        .overlay(Text(String(post.name.prefix(1))).font(.headline).foregroundColor(.white))
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(post.name).font(.subheadline.bold())
                            Text(post.handle).font(.subheadline).foregroundColor(.secondary)
                        }
                        Text(post.body).font(.subheadline)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture { tapped = post }
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
        }
        .listStyle(.plain)
        .isleNotification(item: $tapped) { post in
            Isle.Configuration(
                presentation: .expanded,
                content: .init(
                    leadingImage: UIImage(systemName: "heart.fill"),
                    leadingImageTintColor: .systemPink,
                    title: post.name,
                    subtitle: "liked your post",
                    trailingAccessory: .text(post.handle)),
                autoDismissAfter: 2.5)
        }
    }
}

/// Debug-only harness for iterating on the notification's look and its
/// present/dismiss animation in the Xcode canvas. It draws a faux physical
/// Dynamic Island behind the notification so compact placements can be judged
/// in context, and loops the spring in/out so the animation is visible on
/// repeat. Not compiled for release.
final class IslePreviewHost: UIViewController {

    private let configuration: Isle.Configuration
    private var token: IsleToken?

    init(configuration: Isle.Configuration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var isNotificationVisible = false
    override var prefersStatusBarHidden: Bool { isNotificationVisible }

    override func viewDidLoad() {
        super.viewDidLoad()
        let backdrop = HostingView(customView: DemoFeedView())
        backdrop.frame = view.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backdrop)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentNotification()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        token?.dismiss()
        token = nil
    }

    /// Places the notification exactly as `IsleNotificationCenter` does
    /// (top pinned at the island so the shape contains it) and runs the present
    /// animation once. Refresh the canvas to replay.
    private func presentNotification() {
        token = IsleNotificationCenter.shared.show(configuration, behavior: .replace)

        // Hide the status bar (time/battery) while the notification is up.
        isNotificationVisible = true
        UIView.animate(withDuration: 0.3) { self.setNeedsStatusBarAppearanceUpdate() }
    }
}

/// Preview harness for the camera panel. It intentionally skips starting an
/// `AVCaptureSession`, so the canvas can render the rounded camera surface
/// without hardware access or permission prompts.
final class IsleCameraPreviewHost: UIViewController {

    private var isCameraVisible = false
    override var prefersStatusBarHidden: Bool { isCameraVisible }

    override func viewDidLoad() {
        super.viewDidLoad()
        let backdrop = HostingView(customView: DemoFeedView())
        backdrop.frame = view.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backdrop)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentCamera()
    }

    private func presentCamera() {
        let topInset = view.safeAreaInsets.top
        var camera: IsleCameraView!
        camera = IsleCameraView(
            configuration: .init(),
            topSafeAreaInset: topInset,
            configuresSession: false,
            onCapture: { _ in },
            onDismiss: { [weak self] in
                guard let self else { return }
                camera.animateOut {
                    camera.removeFromSuperview()
                    self.isCameraVisible = false
                    UIView.animate(withDuration: 0.2) {
                        self.setNeedsStatusBarAppearanceUpdate()
                    }
                }
            },
            onError: { _ in }
        )
        view.addSubview(camera)
        NSLayoutConstraint.activate([
            camera.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            camera.topAnchor.constraint(
                equalTo: view.topAnchor,
                constant: Isle.Metrics.shapeTopOffset(topSafeAreaInset: topInset)),
            camera.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Isle.Metrics.sideInset),
            camera.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Isle.Metrics.sideInset),
            camera.heightAnchor.constraint(equalToConstant: Isle.Metrics.cameraHeight(for: view.bounds.height))
        ])
        view.layoutIfNeeded()

        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 0.10, green: 0.12, blue: 0.14, alpha: 1).cgColor,
            UIColor(red: 0.24, green: 0.29, blue: 0.31, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.15, y: 0)
        gradient.endPoint = CGPoint(x: 0.85, y: 1)
        gradient.frame = camera.bounds
        camera.layer.insertSublayer(gradient, at: 0)

        camera.prepareForPresentation()
        camera.animateIn()

        isCameraVisible = true
        UIView.animate(withDuration: 0.3) { self.setNeedsStatusBarAppearanceUpdate() }
    }
}

final class IsleTimerPreviewView: UIStackView {

    private let imageView = UIImageView(image: UIImage(systemName: "timer"))
    private let label = UILabel()
    private var elapsedSeconds = 12
    private var timer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
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
        isLayoutMarginsRelativeArrangement = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        imageView.tintColor = IsleColors.onBackground
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor)
        ])

        label.textColor = IsleColors.onBackground
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        updateLabel()

        addArrangedSubview(imageView)
        addArrangedSubview(label)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            elapsedSeconds += 1
            updateLabel()
        }
    }

    private func updateLabel() {
        label.text = String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }
}

final class IsleRecordingPreviewLabel: UILabel {

    override init(frame: CGRect) {
        super.init(frame: frame)
        text = "REC"
        textColor = IsleColors.onBackground
        font = .systemFont(ofSize: 13, weight: .semibold)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

@available(iOS 17.0, *)
#Preview("Expanded — AirPods") {
    IslePreviewHost(configuration: .init(
        presentation: .expanded,
        content: .init(
            leadingImage: UIImage(systemName: "airpodspro"),
            leadingImageTintColor: IsleColors.onBackground,
            title: "AirPods Pro",
            subtitle: "Connected",
            trailingAccessory: .text("82%")
        ),
        autoDismissAfter: nil))
}

@available(iOS 17.0, *)
#Preview("Compact Pill — Silent") {
    IslePreviewHost(configuration: .init(
        presentation: .compactPill,
        content: .init(
            leadingImage: UIImage(systemName: "bell.slash.fill"),
            leadingImageTintColor: IsleColors.onBackground,
            title: "Silent"
        ),
        autoDismissAfter: nil))
}

@available(iOS 17.0, *)
#Preview("Compact Wrap — Timer") {
    IslePreviewHost(configuration: .init(
        presentation: .compactWrap,
        content: .init(
            leadingView: IsleTimerPreviewView(),
            trailingView: IsleRecordingPreviewLabel()
        ),
        autoDismissAfter: nil))
}

@available(iOS 17.0, *)
#Preview("Compact Wrap — Marquee") {
    IslePreviewHost(configuration: .init(
        presentation: .compactWrap,
        content: .init(
            trailingAccessory: .text("REC"),
            leadingView: {
                let marquee = IsleMarqueeView(
                    text: "Now Playing: Long Song Title That Scrolls",
                    style: .init(font: .monospacedDigitSystemFont(ofSize: 15, weight: .semibold))
                )
                marquee.maxWidth = Isle.Metrics.compactWrapTextMaxWidth
                marquee.setContentHuggingPriority(.required, for: .horizontal)
                return marquee
            }()
        ),
        autoDismissAfter: nil))
}

@available(iOS 17.0, *)
#Preview("Custom SwiftUI content") {
    // Any SwiftUI view drops into a slot by wrapping it in the module's `HostingView`.
    let swiftUICenter = HostingView(
        customView: HStack(spacing: 8) {
            ProgressView().tint(.white)
            Text("Downloading…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .fixedSize()
    )
    IslePreviewHost(configuration: .init(
        presentation: .compactPill,
        content: .init(centerView: swiftUICenter),
        autoDismissAfter: nil))
}

@available(iOS 17.0, *)
#Preview("Confirmation — Camera Access") {
    let confirmation = Isle.makeConfirmationView(
        title: "Camera Access",
        message: "Allow Isle to open the camera?",
        confirmTitle: "OK",
        cancelTitle: "Cancel",
        onConfirm: {},
        onCancel: {}
    )
    IslePreviewHost(configuration: .init(
        presentation: .expanded,
        content: .init(centerView: confirmation),
        autoDismissAfter: nil))
}

@available(iOS 17.0, *)
#Preview("Camera") { IsleCameraPreviewHost() }

@available(iOS 17.0, *)
#Preview("SwiftUI — tap a cell") { DemoFeedView() }
#endif
#endif
