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
    private var currentConfiguration: Isle.Configuration?
    private var dismissTimer: Timer?
    private var presentationID = 0
    private var currentTokenID: UUID?
    private var onDismiss: (() -> Void)?
    private var queue: [QueuedNotification] = []
    private var pendingReplacement: QueuedNotification?
    private var isReplacingCurrent = false

    public init() {}

    /// Presents `configuration`. Any currently visible notification is dismissed first.
    /// Returns a token whose `dismiss()` removes *this* notification (a no-op if it
    /// has already been replaced or dismissed). `onDismiss` fires exactly once, whenever
    /// this presentation ends (auto-dismiss timer, swipe, programmatic `dismiss()`, or
    /// being replaced by a subsequent `show`).
    @discardableResult
    public func show(
        _ configuration: Isle.Configuration,
        behavior: Isle.PresentationBehavior = .replace,
        onDismiss: (() -> Void)? = nil
    ) -> IsleToken {
        switch behavior {
        case .replace:
            queue.removeAll()
            return replaceCurrent(with: configuration, onDismiss: onDismiss)
        case .enqueue:
            guard currentView != nil else {
                return present(configuration, onDismiss: onDismiss)
            }
            let id = UUID()
            queue.append(QueuedNotification(id: id, configuration: configuration, onDismiss: onDismiss))
            return IsleToken { [weak self] in
                guard let self else { return }
                let queuedCount = self.queue.count
                self.queue.removeAll { $0.id == id }
                if self.queue.count == queuedCount {
                    self.dismiss(ifTokenID: id)
                }
            }
        case .bounceIfSame:
            if let currentConfiguration, currentConfiguration.matches(configuration), let currentView {
                currentView.animateRepeatBounce()
                if let style = configuration.haptic {
                    UIImpactFeedbackGenerator(style: style).impactOccurred()
                }
                scheduleAutoDismiss(for: configuration, advancesPresentationID: false)
                return IsleToken { [weak self] in
                    self?.dismiss(ifPresentationID: self?.presentationID ?? -1)
                }
            }
            queue.removeAll()
            return replaceCurrent(with: configuration, onDismiss: onDismiss)
        }
    }

    private func replaceCurrent(
        with configuration: Isle.Configuration,
        onDismiss: (() -> Void)? = nil
    ) -> IsleToken {
        guard let view = currentView else {
            return present(configuration, onDismiss: onDismiss)
        }

        let replacement = QueuedNotification(
            id: UUID(),
            configuration: configuration,
            onDismiss: onDismiss
        )
        pendingReplacement = replacement

        if isReplacingCurrent {
            return IsleToken { [weak self] in
                guard let self else { return }
                if self.pendingReplacement?.id == replacement.id {
                    self.pendingReplacement = nil
                    return
                }
                self.dismiss(ifTokenID: replacement.id)
            }
        }

        let id = presentationID
        dismissTimer?.invalidate()
        dismissTimer = nil
        isReplacingCurrent = true
        view.animateOut { [weak self] in
            guard let self, self.presentationID == id else { return }
            let replacementToPresent = self.pendingReplacement
            self.tearDown()
            self.isReplacingCurrent = false
            self.pendingReplacement = nil
            guard let replacementToPresent else { return }
            _ = self.present(
                replacementToPresent.configuration,
                tokenID: replacementToPresent.id,
                onDismiss: replacementToPresent.onDismiss
            )
        }

        return IsleToken { [weak self] in
            guard let self else { return }
            if self.pendingReplacement?.id == replacement.id {
                self.pendingReplacement = nil
                return
            }
            self.dismiss(ifTokenID: replacement.id)
        }
    }

    private func present(
        _ configuration: Isle.Configuration,
        tokenID: UUID = UUID(),
        onDismiss: (() -> Void)? = nil
    ) -> IsleToken {
        tearDown()
        self.onDismiss = onDismiss
        currentTokenID = tokenID
        currentConfiguration = configuration

        guard let scene = Self.activeWindowScene else {
            currentTokenID = nil
            currentConfiguration = nil
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
        self.currentView = view

        if configuration.allowsSwipeToDismiss {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
            swipe.direction = .up
            view.addGestureRecognizer(swipe)
        }

        if let style = configuration.haptic {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }

        // Defer the expensive layout measurement to the next run loop so the
        // notification can animate in without blocking the main thread. The
        // animation starts from a collapsed transform so the missing width
        // constraint is invisible during the spring animation.
        view.prepareForPresentation()
        view.animateIn()
        RunLoop.current.perform {
            MainActor.assumeIsolated {
                window.layoutIfNeeded()
                view.applyDeferredCompactWrapWidth()
                window.layoutIfNeeded()
            }
        }

        scheduleAutoDismiss(for: configuration, advancesPresentationID: true)
        let idForThisPresentation = presentationID

        return IsleToken { [weak self] in
            self?.dismiss(ifTokenID: tokenID, presentationID: idForThisPresentation)
        }
    }

    /// Dismisses the currently visible notification, if any.
    public func dismiss() {
        dismiss(ifPresentationID: presentationID)
    }

    /// Dismisses the visible notification and clears any queued notifications.
    public func dismissAll() {
        queue.removeAll()
        pendingReplacement = nil
        isReplacingCurrent = false
        guard let view = currentView else {
            tearDown()
            return
        }
        let id = presentationID
        dismissTimer?.invalidate()
        dismissTimer = nil
        view.animateOut { [weak self] in
            guard let self, self.presentationID == id else { return }
            self.tearDown()
        }
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
        let presentedToken = show(configuration, behavior: .replace)
        token = presentedToken
        return presentedToken
    }

    // MARK: - Private

    private func scheduleAutoDismiss(for configuration: Isle.Configuration, advancesPresentationID: Bool) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        if advancesPresentationID {
            presentationID += 1
        }
        let idForThisPresentation = presentationID
        if let seconds = configuration.autoDismissAfter {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.dismiss(ifPresentationID: idForThisPresentation)
                }
            }
        }
    }

    private func dismiss(ifPresentationID id: Int) {
        guard id == presentationID, !isReplacingCurrent, let view = currentView else { return }
        dismissTimer?.invalidate()
        dismissTimer = nil
        view.animateOut { [weak self] in
            guard let self, self.presentationID == id else { return }
            self.tearDown()
            self.presentNextIfNeeded()
        }
    }

    private func dismiss(ifTokenID tokenID: UUID, presentationID id: Int? = nil) {
        if pendingReplacement?.id == tokenID {
            pendingReplacement = nil
            return
        }
        guard currentTokenID == tokenID else { return }
        if let id {
            dismiss(ifPresentationID: id)
        } else {
            dismiss()
        }
    }

    private func tearDown() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentView?.removeFromSuperview()
        currentView = nil
        currentTokenID = nil
        currentConfiguration = nil
        window?.isHidden = true
        window = nil

        let callback = onDismiss
        onDismiss = nil
        callback?()
    }

    private func presentNextIfNeeded() {
        guard !queue.isEmpty else { return }
        let next = queue.removeFirst()
        _ = present(next.configuration, tokenID: next.id, onDismiss: next.onDismiss)
    }

    @objc private func handleSwipeUp() {
        dismiss()
    }

    private static var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

private struct QueuedNotification {
    let id: UUID
    let configuration: Isle.Configuration
    let onDismiss: (() -> Void)?
}

private extension Isle.Configuration {
    func matches(_ other: Isle.Configuration) -> Bool {
        if let id, let otherID = other.id {
            return id == otherID
        }
        return id == nil
            && other.id == nil
            && presentation == other.presentation
            && content.matches(other.content)
    }
}

private extension Isle.Content {
    func matches(_ other: Isle.Content) -> Bool {
        leadingImage == other.leadingImage
            && leadingImageTintColor == other.leadingImageTintColor
            && title == other.title
            && subtitle == other.subtitle
            && trailingAccessory.matches(other.trailingAccessory)
            && showsActivityIndicator == other.showsActivityIndicator
            && leadingView === other.leadingView
            && centerView === other.centerView
            && trailingView === other.trailingView
    }
}

private extension Optional where Wrapped == Isle.Accessory {
    func matches(_ other: Isle.Accessory?) -> Bool {
        switch (self, other) {
        case (.none, .none):
            return true
        case let (.some(.text(left)), .some(.text(right))):
            return left == right
        case let (.some(.image(leftImage, leftTint)), .some(.image(rightImage, rightTint))):
            return leftImage == rightImage && leftTint == rightTint
        default:
            return false
        }
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
