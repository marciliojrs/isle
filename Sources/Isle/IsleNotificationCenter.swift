#if os(iOS)
import UIKit

/// A safe handle to a presented notification, letting callers dismiss it
/// programmatically without exposing the underlying view.
@MainActor
public struct IsleToken {
    private let onDismiss: @MainActor () -> Void
    init(onDismiss: @escaping @MainActor () -> Void) { self.onDismiss = onDismiss }
    public func dismiss() { onDismiss() }
}

/// Presents Dynamic-Island-styled notifications on a dedicated pass-through
/// window that floats above the app's content (including navigation bars) while
/// letting touches outside the notification fall through to the app.
@MainActor
public final class IsleNotificationCenter {

    public static let shared = IsleNotificationCenter()

    private var window: PassthroughWindow?
    private var currentView: IsleView?
    private var dismissTimer: Timer?
    private var presentationID = 0
    private var onDismiss: (() -> Void)?

    public init() {}

    /// Presents `configuration`. Any currently visible notification is removed first.
    /// Returns a token whose `dismiss()` removes *this* notification (a no-op if it
    /// has already been replaced or dismissed). `onDismiss` fires exactly once, whenever
    /// this presentation ends (auto-dismiss timer, swipe, programmatic `dismiss()`, or
    /// being replaced by a subsequent `show`).
    @discardableResult
    public func show(_ configuration: Isle.Configuration, onDismiss: (() -> Void)? = nil) -> IsleToken {
        tearDown()
        self.onDismiss = onDismiss

        guard let scene = Self.activeWindowScene else {
            return IsleToken(onDismiss: {})
        }

        let topInset = scene.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top
            ?? scene.windows.first?.safeAreaInsets.top
            ?? 0

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        // Root VC hides the status bar (time/battery) while the notification is up.
        window.rootViewController = StatusBarHiddenController()
        window.isHidden = false
        self.window = window

        let view = IsleView(configuration: configuration, topSafeAreaInset: topInset)
        window.addSubview(view)
        window.contentView = view

        // The notification's black shape starts at the cutout's top (island floats ~11pt
        // down; the notch is flush with the top) and contains it — the view insets its
        // content below the cutout via the injected safe-area inset — so the island/notch
        // reads as the top of the notification, like the system.
        let topOffset = Isle.Metrics.shapeTopOffset(topSafeAreaInset: topInset)
        let sideInset = Isle.Metrics.sideInset
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            view.topAnchor.constraint(equalTo: window.topAnchor, constant: topOffset),
            view.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: sideInset),
            view.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -sideInset)
        ])
        window.layoutIfNeeded()
        self.currentView = view

        if configuration.allowsSwipeToDismiss {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
            swipe.direction = .up
            view.addGestureRecognizer(swipe)
        }

        if let style = configuration.haptic {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }

        view.prepareForPresentation()
        view.animateIn()

        presentationID += 1
        let idForThisPresentation = presentationID
        if let seconds = configuration.autoDismissAfter {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.dismiss(ifPresentationID: idForThisPresentation)
                }
            }
        }

        return IsleToken { [weak self] in
            self?.dismiss(ifPresentationID: idForThisPresentation)
        }
    }

    /// Dismisses the currently visible notification, if any.
    public func dismiss() {
        dismiss(ifPresentationID: presentationID)
    }

    /// Presents a confirmation prompt using the same Isle overlay lifecycle as
    /// notifications. The prompt stays visible until the user taps one of the
    /// actions, swipes it away, or it is dismissed programmatically.
    @discardableResult
    public func showConfirmation(
        title: String,
        message: String? = nil,
        confirmTitle: String = "OK",
        cancelTitle: String = "Cancel",
        haptic: UIImpactFeedbackGenerator.FeedbackStyle? = .soft,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> IsleToken {
        var token: IsleToken?
        let confirmationView = Isle.makeConfirmationView(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            onConfirm: {
                onConfirm()
                token?.dismiss()
            },
            onCancel: {
                onCancel?()
                token?.dismiss()
            }
        )

        let configuration = Isle.Configuration(
            presentation: .expanded,
            content: Isle.Content(centerView: confirmationView),
            autoDismissAfter: nil,
            allowsSwipeToDismiss: true,
            haptic: haptic
        )
        let presentedToken = show(configuration)
        token = presentedToken
        return presentedToken
    }

    // MARK: - Private

    private func dismiss(ifPresentationID id: Int) {
        guard id == presentationID, let view = currentView else { return }
        dismissTimer?.invalidate()
        dismissTimer = nil
        view.animateOut { [weak self] in
            guard let self, self.presentationID == id else { return }
            self.tearDown()
        }
    }

    private func tearDown() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentView?.removeFromSuperview()
        currentView = nil
        window?.isHidden = true
        window = nil

        let callback = onDismiss
        onDismiss = nil
        callback?()
    }

    @objc private func handleSwipeUp() {
        dismiss()
    }

    private static var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

/// A window that only intercepts touches landing on its notification content;
/// every other touch passes through to the app windows below.
private final class PassthroughWindow: UIWindow {
    weak var contentView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let contentView else { return nil }
        let pointInContent = convert(point, to: contentView)
        guard contentView.point(inside: pointInContent, with: event) else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// Root controller for the overlay window whose only job is to hide the status bar
/// (time/battery) while the notification is presented. Its view is transparent and
/// non-interactive so touches still fall through via `PassthroughWindow.hitTest`.
private final class StatusBarHiddenController: UIViewController {
    override var prefersStatusBarHidden: Bool { true }

    override func loadView() {
        let container = UIView()
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false
        view = container
    }
}
#endif
