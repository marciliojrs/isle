#if os(iOS)
import AVFoundation
import UIKit

@MainActor
public struct IsleCameraToken {
    private let onDismiss: @MainActor () -> Void
    init(onDismiss: @escaping @MainActor () -> Void) { self.onDismiss = onDismiss }
    public func dismiss() { onDismiss() }
}

/// Presents Isle's camera overlay on a dedicated top-level window.
@MainActor
public final class IsleCameraCenter {

    public static let shared = IsleCameraCenter()

    private var window: CameraPassthroughWindow?
    private var currentView: IsleCameraView?
    private var presentationID = 0
    private var onDismiss: (() -> Void)?

    public init() {}

    @discardableResult
    public func showCamera(
        configuration: Isle.CameraConfiguration = Isle.CameraConfiguration(),
        onCapture: @escaping (UIImage) -> Void,
        onDismiss: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> IsleCameraToken {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return presentCamera(
                configuration: configuration,
                onCapture: onCapture,
                onDismiss: onDismiss,
                onError: onError
            )
        case .notDetermined:
            let confirmationToken = IsleNotificationCenter.shared.showConfirmation(
                title: configuration.permissionTitle,
                message: configuration.permissionMessage,
                confirmTitle: configuration.permissionConfirmTitle,
                cancelTitle: configuration.permissionCancelTitle,
                haptic: configuration.haptic,
                onConfirm: { [weak self] in
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        DispatchQueue.main.async {
                            MainActor.assumeIsolated {
                                guard let self else { return }
                                if granted {
                                    _ = self.presentCamera(
                                        configuration: configuration,
                                        onCapture: onCapture,
                                        onDismiss: onDismiss,
                                        onError: onError
                                    )
                                } else {
                                    onError?(IsleCameraError.permissionDenied)
                                }
                            }
                        }
                    }
                },
                onCancel: {
                    onDismiss?()
                }
            )
            return IsleCameraToken {
                confirmationToken.dismiss()
            }
        case .denied, .restricted:
            onError?(IsleCameraError.permissionDenied)
            return IsleCameraToken(onDismiss: {})
        @unknown default:
            onError?(IsleCameraError.permissionDenied)
            return IsleCameraToken(onDismiss: {})
        }
    }

    public func dismiss() {
        dismiss(ifPresentationID: presentationID)
    }

    private func presentCamera(
        configuration: Isle.CameraConfiguration,
        onCapture: @escaping (UIImage) -> Void,
        onDismiss: (() -> Void)?,
        onError: ((Error) -> Void)?
    ) -> IsleCameraToken {
        tearDown()
        self.onDismiss = onDismiss

        guard let scene = Self.activeWindowScene else {
            return IsleCameraToken(onDismiss: {})
        }

        let topInset = scene.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top
            ?? scene.windows.first?.safeAreaInsets.top
            ?? 0

        let window = CameraPassthroughWindow(windowScene: scene)
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        // Root VC hides the status bar (time/battery) while the camera is up.
        window.rootViewController = CameraStatusBarHiddenController()
        window.isHidden = false
        window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
        self.window = window

        presentationID += 1
        let idForThisPresentation = presentationID

        let cameraView = IsleCameraView(
            configuration: configuration,
            topSafeAreaInset: topInset,
            onCapture: { [weak self] image in
                onCapture(image)
                if configuration.dismissesAfterCapture {
                    self?.dismiss(ifPresentationID: idForThisPresentation)
                }
            },
            onDismiss: { [weak self] in
                self?.dismiss(ifPresentationID: idForThisPresentation)
            },
            onError: { error in
                onError?(error)
            }
        )

        window.addSubview(cameraView)
        window.contentView = cameraView

        let topOffset = Isle.Metrics.shapeTopOffset(topSafeAreaInset: topInset)
        let sideInset = Isle.Metrics.sideInset
        NSLayoutConstraint.activate([
            cameraView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            cameraView.topAnchor.constraint(equalTo: window.topAnchor, constant: topOffset),
            cameraView.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: sideInset),
            cameraView.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -sideInset),
            cameraView.heightAnchor.constraint(equalToConstant: Isle.Metrics.cameraHeight(for: scene.coordinateSpace.bounds.height))
        ])
        window.layoutIfNeeded()
        self.currentView = cameraView

        if configuration.allowsSwipeToDismiss {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
            swipe.direction = .up
            cameraView.addGestureRecognizer(swipe)
        }

        if let style = configuration.haptic {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }

        cameraView.prepareForPresentation()
        cameraView.animateIn()
        cameraView.startCamera()

        return IsleCameraToken { [weak self] in
            self?.dismiss(ifPresentationID: idForThisPresentation)
        }
    }

    private func dismiss(ifPresentationID id: Int) {
        guard id == presentationID, let view = currentView else { return }
        view.stopCamera()
        view.animateOut { [weak self] in
            guard let self, self.presentationID == id else { return }
            self.tearDown()
        }
    }

    private func tearDown() {
        currentView?.stopCamera()
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

private final class CameraPassthroughWindow: UIWindow {
    weak var contentView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let contentView else { return nil }
        let pointInContent = convert(point, to: contentView)
        guard contentView.point(inside: pointInContent, with: event) else { return nil }
        return super.hitTest(point, with: event)
    }
}

private final class CameraStatusBarHiddenController: UIViewController {
    override var prefersStatusBarHidden: Bool { true }

    override func loadView() {
        let container = UIView()
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false
        view = container
    }
}
#endif
