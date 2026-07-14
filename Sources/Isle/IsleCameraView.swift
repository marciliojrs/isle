#if os(iOS)
@preconcurrency import AVFoundation
import UIKit

@MainActor
public final class IsleCameraView: UIView {

    private let configuration: Isle.CameraConfiguration
    private let topSafeAreaInset: CGFloat
    private let onCapture: (UIImage) -> Void
    private let onError: (Error) -> Void

    nonisolated(unsafe) private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "dev.isle.camera.session")
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoDelegate: PhotoCaptureDelegate?

    private lazy var shutterButton = makeShutterButton()
    private lazy var closeButton = makeCloseButton()

    public convenience init(
        configuration: Isle.CameraConfiguration,
        topSafeAreaInset: CGFloat,
        onCapture: @escaping (UIImage) -> Void,
        onDismiss: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.init(
            configuration: configuration,
            topSafeAreaInset: topSafeAreaInset,
            configuresSession: true,
            onCapture: onCapture,
            onDismiss: onDismiss,
            onError: onError
        )
    }

    init(
        configuration: Isle.CameraConfiguration,
        topSafeAreaInset: CGFloat,
        configuresSession: Bool,
        onCapture: @escaping (UIImage) -> Void,
        onDismiss: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.configuration = configuration
        self.topSafeAreaInset = topSafeAreaInset
        self.onCapture = onCapture
        self.onError = onError
        self.onDismiss = onDismiss
        super.init(frame: .zero)
        configureContainer()
        buildChrome()
        if configuresSession {
            configureSession()
        }
    }

    private let onDismiss: () -> Void

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    deinit {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func configureContainer() {
        backgroundColor = IsleColors.background
        layer.cornerRadius = Isle.Metrics.cameraCornerRadius
        layer.masksToBounds = true
        if Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) == .notch {
            layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        updateContainerBorder()
        translatesAutoresizingMaskIntoConstraints = false
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateContainerBorder()
    }

    private func updateContainerBorder() {
        guard traitCollection.userInterfaceStyle == .dark else {
            layer.borderWidth = 0
            layer.borderColor = nil
            return
        }
        layer.borderWidth = 1 / max(UIScreen.main.scale, 1)
        layer.borderColor = IsleColors.darkModeBorder.cgColor
    }

    private func buildChrome() {
        addSubview(shutterButton)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            shutterButton.widthAnchor.constraint(equalToConstant: 66),
            shutterButton.heightAnchor.constraint(equalTo: shutterButton.widthAnchor),

            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalTo: closeButton.widthAnchor)
        ])
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            do {
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    throw IsleCameraError.cameraUnavailable
                }
                let input = try AVCaptureDeviceInput(device: camera)
                guard self.session.canAddInput(input), self.session.canAddOutput(self.photoOutput) else {
                    throw IsleCameraError.configurationFailed
                }
                self.session.addInput(input)
                self.session.addOutput(self.photoOutput)
                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self.installPreviewLayer()
                    }
                }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self.onError(error)
                    }
                }
            }
        }
    }

    private func installPreviewLayer() {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    public func startCamera() {
        sessionQueue.async { [session] in
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    public func stopCamera() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    @objc private func capturePhoto() {
        if let style = configuration.captureHaptic {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto

        let delegate = PhotoCaptureDelegate { [weak self] result in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    switch result {
                    case .success(let image):
                        self.onCapture(image)
                    case .failure(let error):
                        self.onError(error)
                    }
                    self.photoDelegate = nil
                }
            }
        }
        photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    @objc private func close() {
        onDismiss()
    }

    private func makeShutterButton() -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = IsleColors.onBackground
        button.layer.cornerRadius = 33
        button.layer.borderColor = UIColor(white: 1, alpha: 0.5).cgColor
        button.layer.borderWidth = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Take Photo"
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        return button
    }

    private func makeCloseButton() -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "xmark")
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = IsleColors.surface
        configuration.baseForegroundColor = IsleColors.onBackground

        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Close Camera"
        button.addTarget(self, action: #selector(close), for: .touchUpInside)
        return button
    }

    private var collapsedTransform: CGAffineTransform {
        guard bounds.height > 0 else { return CGAffineTransform(scaleX: 0.2, y: 0.2) }
        switch Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) {
        case .dynamicIsland:
            let scale: CGFloat = 0.2
            let cutoutHeight = Isle.Metrics.cutoutHeight(topSafeAreaInset: topSafeAreaInset)
            let shift = cutoutHeight / 2 - bounds.height / 2
            return CGAffineTransform(translationX: 0, y: shift).scaledBy(x: scale, y: scale)
        case .notch, .none:
            // Camera panels should feel like they open from the notch/top edge,
            // not like a banner sliding in from offscreen.
            return CGAffineTransform(scaleX: 1, y: 0.02)
        }
    }

    private var dismissalTransform: CGAffineTransform {
        guard bounds.height > 0 else { return CGAffineTransform(scaleX: 0.2, y: 0.2) }
        switch Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) {
        case .dynamicIsland:
            let targetWidth = Isle.Metrics.islandWidth
            let targetHeight = Isle.Metrics.islandHeight
            let scaleX = min(targetWidth / max(bounds.width, 1), 1)
            let scaleY = min(targetHeight / max(bounds.height, 1), 1)
            let shift = targetHeight / 2 - bounds.height / 2
            return CGAffineTransform(translationX: 0, y: shift).scaledBy(x: scaleX, y: scaleY)
        case .notch, .none:
            let offset = bounds.height + Isle.Metrics.shapeTopOffset(topSafeAreaInset: topSafeAreaInset)
            return CGAffineTransform(translationX: 0, y: -offset)
        }
    }

    public func prepareForPresentation() {
        if Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) == .dynamicIsland {
            setLayerAnchorPoint(CGPoint(x: 0.5, y: 0.5))
        } else {
            setLayerAnchorPoint(CGPoint(x: 0.5, y: 0))
        }
        alpha = 0
        transform = collapsedTransform
    }

    public func animateIn() {
        switch Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) {
        case .dynamicIsland:
            animateIslandIn()
        case .notch, .none:
            animateTopExpandIn()
        }
    }

    private func animateIslandIn() {
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.74,
            initialSpringVelocity: 0.7,
            options: [.curveEaseOut]
        ) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    private func animateTopExpandIn() {
        UIView.animate(
            withDuration: 0.38,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            self.alpha = 1
            self.transform = .identity
        } completion: { _ in
            UIView.animate(
                withDuration: 0.11,
                delay: 0,
                options: [.curveEaseOut]
            ) {
                self.transform = CGAffineTransform(scaleX: 1, y: 1.018)
            } completion: { _ in
                UIView.animate(
                    withDuration: 0.13,
                    delay: 0,
                    options: [.curveEaseInOut]
                ) {
                    self.transform = .identity
                }
            }
        }
    }

    public func animateOut(completion: @escaping () -> Void) {
        if Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) == .dynamicIsland {
            setLayerAnchorPoint(CGPoint(x: 0.5, y: 0.5))
        } else {
            setLayerAnchorPoint(CGPoint(x: 0.5, y: 0))
        }
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            options: [.curveEaseIn]
        ) {
            self.alpha = 0
            self.transform = self.dismissalTransform
        } completion: { _ in
            completion()
        }
    }

    private func setLayerAnchorPoint(_ anchorPoint: CGPoint) {
        guard layer.anchorPoint != anchorPoint else { return }
        let oldOrigin = frame.origin
        layer.anchorPoint = anchorPoint
        let newOrigin = frame.origin
        layer.position = CGPoint(
            x: layer.position.x - newOrigin.x + oldOrigin.x,
            y: layer.position.y - newOrigin.y + oldOrigin.y
        )
    }
}

public enum IsleCameraError: Error {
    case cameraUnavailable
    case configurationFailed
    case permissionDenied
    case captureFailed
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<UIImage, Error>) -> Void

    init(completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }
        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else {
            completion(.failure(IsleCameraError.captureFailed))
            return
        }
        completion(.success(image))
    }
}
#endif
