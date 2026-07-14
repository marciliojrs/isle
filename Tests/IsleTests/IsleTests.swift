#if os(iOS)
import Testing
import UIKit
@testable import Isle

@Suite("Isle — Configuration")
struct IsleConfigurationTests {

    @Test("Configuration defaults: 3s auto-dismiss, swipe enabled")
    func configurationDefaults() {
        let config = Isle.Configuration(
            presentation: .expanded,
            content: Isle.Content(title: "Hi")
        )
        #expect(config.id == nil)
        #expect(config.autoDismissAfter == 3)
        #expect(config.allowsSwipeToDismiss == true)
    }

    @Test("Configuration accepts a stable identifier for repeat detection")
    func configurationIdentifier() {
        let config = Isle.Configuration(
            id: "network-error",
            presentation: .compactPill,
            content: Isle.Content(title: "Offline")
        )
        #expect(config.id == "network-error")
    }

    @Test("Content defaults: all optionals nil")
    func contentDefaults() {
        let content = Isle.Content()
        #expect(content.leadingImage == nil)
        #expect(content.leadingImageTintColor == nil)
        #expect(content.title == nil)
        #expect(content.subtitle == nil)
        #expect(content.trailingAccessory == nil)
        #expect(content.showsActivityIndicator == false)
    }

    @Test("connectionIssue preset is a compact pill with the given message and red tint")
    func connectionIssuePreset() {
        let config = Isle.Configuration.connectionIssue(message: "You are offline")
        #expect(config.presentation == .compactPill)
        #expect(config.content.title == "You are offline")
        #expect(config.content.leadingImageTintColor == IsleColors.critical)
        #expect(config.content.leadingImage != nil)
    }

    @Test("Camera configuration defaults are permission-first and dismiss after capture")
    func cameraConfigurationDefaults() {
        let config = Isle.CameraConfiguration()
        #expect(config.permissionTitle == "Camera Access")
        #expect(config.permissionConfirmTitle == "OK")
        #expect(config.permissionCancelTitle == "Cancel")
        #expect(config.allowsSwipeToDismiss == true)
        #expect(config.dismissesAfterCapture == true)
        #expect(config.haptic == .soft)
        #expect(config.captureHaptic == .medium)
    }
}

@Suite("Isle — Metrics")
struct IsleMetricsTests {

    @Test("Island devices (>= 51pt top inset) are detected as having an island")
    func detectsIsland() {
        #expect(Isle.Metrics.hasDynamicIsland(topSafeAreaInset: 59) == true)
        #expect(Isle.Metrics.hasDynamicIsland(topSafeAreaInset: 51) == true)
    }

    @Test("Notch and flat-top devices (< 51pt top inset) are not treated as island")
    func detectsNonIsland() {
        #expect(Isle.Metrics.hasDynamicIsland(topSafeAreaInset: 50) == false)
        #expect(Isle.Metrics.hasDynamicIsland(topSafeAreaInset: 47) == false)
        #expect(Isle.Metrics.hasDynamicIsland(topSafeAreaInset: 20) == false)
    }

    @Test("Camera height is half the window with a practical minimum")
    func cameraHeight() {
        #expect(Isle.Metrics.cameraHeight(for: 800) == 400)
        #expect(Isle.Metrics.cameraHeight(for: 500) == 320)
    }
}

@MainActor
@Suite("IsleView — appearance")
struct IsleViewTests {

    private func makeView(_ presentation: Isle.Presentation) -> IsleView {
        IsleView(
            configuration: Isle.Configuration(
                presentation: presentation,
                content: Isle.Content(title: "Title", subtitle: "Subtitle")
            ),
            topSafeAreaInset: 59
        )
    }

    @Test("Expanded uses the large corner radius")
    func expandedCornerRadius() {
        let view = makeView(.expanded)
        #expect(view.layer.cornerRadius == Isle.Metrics.expandedCornerRadius)
    }

    @Test("Compact presentations use the pill corner radius")
    func compactCornerRadius() {
        #expect(makeView(.compactPill).layer.cornerRadius == Isle.Metrics.compactCornerRadius)
        #expect(makeView(.compactWrap).layer.cornerRadius == Isle.Metrics.compactCornerRadius)
    }

    @Test("Container background uses the design-system black")
    func containerBackground() {
        #expect(makeView(.expanded).backgroundColor == IsleColors.background)
    }

    @Test("An activity indicator is built when showsActivityIndicator is true")
    func buildsActivityIndicator() {
        let view = IsleView(
            configuration: Isle.Configuration(
                presentation: .compactPill,
                content: Isle.Content(title: "Syncing", showsActivityIndicator: true)
            ),
            topSafeAreaInset: 59
        )
        func containsIndicator(_ candidate: UIView) -> Bool {
            candidate is UIActivityIndicatorView || candidate.subviews.contains(where: containsIndicator)
        }
        #expect(containsIndicator(view))
    }

    @Test("No activity indicator is built when showsActivityIndicator is false")
    func omitsActivityIndicator() {
        let view = makeView(.compactPill)
        func containsIndicator(_ candidate: UIView) -> Bool {
            candidate is UIActivityIndicatorView || candidate.subviews.contains(where: containsIndicator)
        }
        #expect(containsIndicator(view) == false)
    }

    private func contains(_ root: UIView, _ target: UIView) -> Bool {
        root === target || root.subviews.contains { contains($0, target) }
    }

    private func resolveStyle(_ style: UIUserInterfaceStyle, for view: UIView) {
        let parent = UIViewController()
        parent.overrideUserInterfaceStyle = style
        parent.view.addSubview(view)
        view.frame = CGRect(x: 0, y: 0, width: 240, height: 80)
        view.layoutIfNeeded()
    }

    @Test("Custom leading/center/trailing views are used in the expanded layout")
    func expandedCustomViews() {
        let leading = UIView(), center = UIView(), trailing = UIView()
        let view = IsleView(
            configuration: .init(
                presentation: .expanded,
                content: .init(leadingView: leading, centerView: center, trailingView: trailing)),
            topSafeAreaInset: 59)
        #expect(contains(view, leading))
        #expect(contains(view, center))
        #expect(contains(view, trailing))
    }

    @Test("Custom center view is used in the compact pill")
    func compactPillCustomCenter() {
        let center = UIView()
        let view = IsleView(
            configuration: .init(presentation: .compactPill, content: .init(centerView: center)),
            topSafeAreaInset: 59)
        #expect(contains(view, center))
    }

    @Test("Custom leading/trailing views are used in the compact wrap")
    func compactWrapCustomViews() {
        let leading = UIView(), trailing = UIView()
        let view = IsleView(
            configuration: .init(presentation: .compactWrap, content: .init(leadingView: leading, trailingView: trailing)),
            topSafeAreaInset: 59)
        #expect(contains(view, leading))
        #expect(contains(view, trailing))
    }

    @Test("Compact wrap stays snug on Dynamic Island devices")
    func compactWrapSnugOnDynamicIsland() {
        let view = IsleView(
            configuration: .init(
                presentation: .compactWrap,
                content: .init(
                    leadingImage: UIImage(systemName: "timer"),
                    title: "0:12",
                    trailingAccessory: .text("REC")
                )
            ),
            topSafeAreaInset: 59
        )
        let size = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        #expect(size.width < 320)
    }

    @Test("Compact wrap timer width fits content on Dynamic Island devices")
    func compactWrapTimerWidthFitsContentOnDynamicIsland() {
        let view = IsleView(
            configuration: .init(
                presentation: .compactWrap,
                content: .init(
                    leadingImage: UIImage(systemName: "timer"),
                    title: "12:34",
                    trailingAccessory: .text("REC")
                )
            ),
            topSafeAreaInset: 59
        )
        let size = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        #expect(size.width < 340)
    }

    @Test("Compact wrap leading content ends at the cutout leading edge")
    func compactWrapLeadingContentAlignsWithCutoutLeadingEdge() {
        let leading = UILabel()
        leading.text = "0:12"
        let view = IsleView(
            configuration: .init(
                presentation: .compactWrap,
                content: .init(
                    leadingView: leading,
                    trailingAccessory: .text("REC")
                )
            ),
            topSafeAreaInset: 59
        )

        let size = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()

        let cutoutLeadingEdge = size.width / 2 - Isle.Metrics.cutoutWidth(topSafeAreaInset: 59) / 2
        #expect(abs(leading.frame.maxX - cutoutLeadingEdge) < 0.5)
    }

    @Test("Compact wrap trailing content is fixed to the trailing edge")
    func compactWrapTrailingContentAlignsWithTrailingEdge() {
        let trailing = UILabel()
        trailing.text = "REC"
        let view = IsleView(
            configuration: .init(
                presentation: .compactWrap,
                content: .init(
                    leadingImage: UIImage(systemName: "timer"),
                    title: "0:12",
                    trailingView: trailing
                )
            ),
            topSafeAreaInset: 59
        )

        let size = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()

        let expectedTrailing = size.width - Isle.Metrics.contentInsets.right
        #expect(abs(trailing.frame.maxX - expectedTrailing) < 0.5)
    }

    @Test("Notification container shows a light border in dark mode")
    func notificationBorderInDarkMode() {
        let view = makeView(.expanded)
        resolveStyle(.dark, for: view)
        view.traitCollectionDidChange(nil)

        #expect(view.layer.borderWidth > 0)
        #expect(view.layer.borderColor == IsleColors.darkModeBorder.cgColor)
    }

    @Test("Notification container has no border in light mode")
    func notificationBorderInLightMode() {
        let view = makeView(.expanded)
        resolveStyle(.light, for: view)
        view.traitCollectionDidChange(nil)

        #expect(view.layer.borderWidth == 0)
        #expect(view.layer.borderColor == nil)
    }
}

@MainActor
@Suite("Isle — confirmation")
struct IsleConfirmationTests {

    private func allSubviews(of root: UIView) -> [UIView] {
        root.subviews + root.subviews.flatMap(allSubviews)
    }

    @Test("Confirmation view includes confirm and cancel buttons")
    func confirmationButtons() {
        let view = Isle.makeConfirmationView(
            title: "Camera Access",
            message: "Allow Isle to use the camera?",
            confirmTitle: "OK",
            cancelTitle: "Cancel",
            onConfirm: {},
            onCancel: {}
        )
        let buttons = allSubviews(of: view).compactMap { $0 as? UIButton }
        #expect(buttons.count == 2)
        #expect(buttons.contains { $0.accessibilityLabel == "OK" })
        #expect(buttons.contains { $0.accessibilityLabel == "Cancel" })
    }

    @Test("Confirmation buttons invoke their actions")
    func confirmationButtonActions() {
        var didConfirm = false
        var didCancel = false
        let view = Isle.makeConfirmationView(
            title: "Camera Access",
            message: "Allow Isle to use the camera?",
            confirmTitle: "OK",
            cancelTitle: "Cancel",
            onConfirm: { didConfirm = true },
            onCancel: { didCancel = true }
        )
        let buttons = allSubviews(of: view).compactMap { $0 as? UIButton }

        buttons.first { $0.accessibilityLabel == "OK" }?.sendActions(for: .touchUpInside)
        buttons.first { $0.accessibilityLabel == "Cancel" }?.sendActions(for: .touchUpInside)

        #expect(didConfirm)
        #expect(didCancel)
    }

    @Test("Confirmation message label is hidden when message is nil")
    func confirmationWithoutMessage() {
        let view = Isle.makeConfirmationView(
            title: "Camera Access",
            message: nil,
            confirmTitle: "OK",
            cancelTitle: "Cancel",
            onConfirm: {},
            onCancel: {}
        )
        let labels = allSubviews(of: view).compactMap { $0 as? UILabel }
        #expect(labels.contains { $0.text == "Camera Access" })
        #expect(labels.contains { $0.text == nil && $0.isHidden })
    }
}

@MainActor
@Suite("IsleCameraView — appearance")
struct IsleCameraViewTests {

    private func allSubviews(of root: UIView) -> [UIView] {
        root.subviews + root.subviews.flatMap(allSubviews)
    }

    private func makeView() -> IsleCameraView {
        IsleCameraView(
            configuration: .init(),
            topSafeAreaInset: 59,
            configuresSession: false,
            onCapture: { _ in },
            onDismiss: {},
            onError: { _ in }
        )
    }

    private func resolveStyle(_ style: UIUserInterfaceStyle, for view: UIView) {
        let parent = UIViewController()
        parent.overrideUserInterfaceStyle = style
        parent.view.addSubview(view)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 360)
        view.layoutIfNeeded()
    }

    @Test("Camera view uses camera corner radius and black background")
    func cameraContainerAppearance() {
        let view = makeView()
        #expect(view.layer.cornerRadius == Isle.Metrics.cameraCornerRadius)
        #expect(view.backgroundColor == IsleColors.background)
    }

    @Test("Camera view rounds all corners on Dynamic Island devices")
    func cameraIslandCorners() {
        let view = IsleCameraView(
            configuration: .init(),
            topSafeAreaInset: 59,
            configuresSession: false,
            onCapture: { _ in },
            onDismiss: {},
            onError: { _ in }
        )
        #expect(view.layer.maskedCorners == [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner])
    }

    @Test("Camera view rounds only bottom corners on notch devices")
    func cameraNotchCorners() {
        let view = IsleCameraView(
            configuration: .init(),
            topSafeAreaInset: 47,
            configuresSession: false,
            onCapture: { _ in },
            onDismiss: {},
            onError: { _ in }
        )
        #expect(view.layer.maskedCorners == [.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
    }

    @Test("Camera view includes shutter and close buttons")
    func cameraControls() {
        let view = makeView()
        let buttons = allSubviews(of: view).compactMap { $0 as? UIButton }
        #expect(buttons.contains { $0.accessibilityLabel == "Take Photo" })
        #expect(buttons.contains { $0.accessibilityLabel == "Close Camera" })
    }

    @Test("Camera close button invokes dismiss")
    func closeButtonDismisses() {
        var didDismiss = false
        let view = IsleCameraView(
            configuration: .init(),
            topSafeAreaInset: 59,
            configuresSession: false,
            onCapture: { _ in },
            onDismiss: { didDismiss = true },
            onError: { _ in }
        )
        let closeButton = allSubviews(of: view)
            .compactMap { $0 as? UIButton }
            .first { $0.accessibilityLabel == "Close Camera" }

        closeButton?.sendActions(for: .touchUpInside)

        #expect(didDismiss)
    }

    @Test("Camera container shows a light border in dark mode")
    func cameraBorderInDarkMode() {
        let view = makeView()
        resolveStyle(.dark, for: view)
        view.traitCollectionDidChange(nil)

        #expect(view.layer.borderWidth > 0)
        #expect(view.layer.borderColor == IsleColors.darkModeBorder.cgColor)
    }

    @Test("Camera container has no border in light mode")
    func cameraBorderInLightMode() {
        let view = makeView()
        resolveStyle(.light, for: view)
        view.traitCollectionDidChange(nil)

        #expect(view.layer.borderWidth == 0)
        #expect(view.layer.borderColor == nil)
    }
}
#endif
