#if os(iOS)
import UIKit

/// Pure display component that renders a Dynamic-Island-styled notification.
///
/// It builds its subviews for the chosen `Presentation` and animates itself
/// open/closed from the island footprint. It owns no window and no timer —
/// `IsleNotificationCenter` handles the presentation lifecycle.
@MainActor
public final class IsleView: UIView {

    public let configuration: Isle.Configuration
    private let hasDynamicIsland: Bool
    private let topSafeAreaInset: CGFloat

    private lazy var titleLabel = makeTitleLabel()
    private lazy var subtitleLabel = makeSubtitleLabel()
    private lazy var leadingImageView = makeLeadingImageView()
    private lazy var trailingAccessoryView = makeTrailingAccessoryView()
    private lazy var activityIndicator = makeActivityIndicator()
    /// Reference to the compact-wrap leading view for deferred width measurement.
    private var compactWrapLeadingView: UIView?
    private var compactWrapWidthConstraint: NSLayoutConstraint?

    /// - Parameters:
    ///   - configuration: content + presentation to render.
    ///   - topSafeAreaInset: the presenting window's top safe-area inset, used to
    ///     decide island vs notch layout. Injected for testability.
    public init(
        configuration: Isle.Configuration,
        topSafeAreaInset: CGFloat
    ) {
        self.configuration = configuration
        self.hasDynamicIsland = Isle.Metrics.hasDynamicIsland(
            topSafeAreaInset: topSafeAreaInset
        )
        self.topSafeAreaInset = topSafeAreaInset
        super.init(frame: .zero)
        configureContainer()
        buildContent()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Container

    private func configureContainer() {
        backgroundColor = IsleColors.background
        layer.masksToBounds = true
        let isIsland = Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) == .dynamicIsland
        layer.cornerRadius = configuration.presentation == .expanded
            ? Isle.Metrics.expandedCornerRadius
            : (isIsland ? Isle.Metrics.compactCornerRadius
                : Isle.Metrics.screenCornerRadius(topSafeAreaInset: topSafeAreaInset))
        // The notch sits flush with the screen's top edge, so round only the bottom
        // corners (a square top hugs the top edge). The island floats, so round all four.
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

    // MARK: - Content

    /// Top inset that pushes content below the physical island/notch so the camera
    /// cutout stays clear. The device's top safe-area inset encodes the island/notch
    /// height; the shape itself starts at the island's top (so the island reads as the
    /// top of the notification), hence the offset back by `islandTopInset`.
    private var contentTopInset: CGFloat {
        max(topSafeAreaInset - Isle.Metrics.shapeTopOffset(topSafeAreaInset: topSafeAreaInset),
            Isle.Metrics.contentInsets.top)
    }

    private func buildContent() {
        switch configuration.presentation {
        case .expanded: buildExpanded()
        case .compactWrap: buildCompactWrap()
        case .compactPill: buildCompactPill()
        }
    }

    private func buildExpanded() {
        let insets = Isle.Metrics.contentInsets

        // Each slot uses a caller-supplied custom view when set, else the built-in content.
        let leadingView = configuration.content.leadingView
            ?? (configuration.content.showsActivityIndicator ? activityIndicator
                : (configuration.content.leadingImage != nil ? leadingImageView : nil))
        let trailingView = configuration.content.trailingView
            ?? (configuration.content.trailingAccessory != nil ? trailingAccessoryView : nil)
        let center = configuration.content.centerView ?? makeExpandedTextBlock()

        center.translatesAutoresizingMaskIntoConstraints = false
        addSubview(center)

        var constraints: [NSLayoutConstraint] = [
            center.topAnchor.constraint(equalTo: topAnchor, constant: contentTopInset),
            center.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom)
        ]

        if let leadingView {
            leadingView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(leadingView)
            constraints += [
                leadingView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
                leadingView.centerYAnchor.constraint(equalTo: centerYAnchor),
                center.leadingAnchor.constraint(equalTo: leadingView.trailingAnchor, constant: 12)
            ]
        } else {
            constraints.append(center.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left))
        }

        if let trailingView {
            trailingView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(trailingView)
            constraints += [
                trailingView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
                trailingView.centerYAnchor.constraint(equalTo: centerYAnchor),
                center.trailingAnchor.constraint(equalTo: trailingView.leadingAnchor, constant: -12)
            ]
        } else {
            constraints.append(center.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right))
        }

        NSLayoutConstraint.activate(constraints)
    }

    /// Built-in expanded center: title over subtitle, each filling the block's width so
    /// the title never collapses while the subtitle stays full.
    private func makeExpandedTextBlock() -> UIView {
        let block = UIView()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        block.addSubview(titleLabel)
        block.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: block.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: block.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: block.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: block.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: block.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: block.bottomAnchor)
        ])
        return block
    }

    /// Built-in compact content: activity indicator + leading image + title, in a row.
    private func makeCompactContentStack() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.setContentHuggingPriority(.required, for: .horizontal)
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)
        if configuration.content.showsActivityIndicator { stack.addArrangedSubview(activityIndicator) }
        if configuration.content.leadingImage != nil { stack.addArrangedSubview(leadingImageView) }
        if configuration.content.title != nil { stack.addArrangedSubview(makeCompactTitleView()) }
        return stack
    }

    private func makeCompactTitleView() -> UIView {
        makeCompactTextView(
            configuration.content.title,
            font: .systemFont(ofSize: 13, weight: .semibold),
            maxWidth: configuration.presentation == .compactWrap
                ? Isle.Metrics.compactWrapTextMaxWidth
                : Isle.Metrics.compactPillTextMaxWidth
        )
    }

    private func makeCompactTextView(_ text: String?, font: UIFont, maxWidth: CGFloat) -> UIView {
        let measuredWidth = ((text ?? "") as NSString).size(withAttributes: [.font: font]).width
        guard measuredWidth > maxWidth else {
            let label = UILabel()
            label.textColor = IsleColors.onBackground
            label.font = font
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            label.text = text
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            return label
        }

        let marquee = IsleMarqueeView(
            text: text,
            style: .init(
                font: font,
                textColor: IsleColors.onBackground
            )
        )
        marquee.maxWidth = maxWidth
        marquee.setContentHuggingPriority(.required, for: .horizontal)
        marquee.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return marquee
    }

    private func buildCompactWrap() {
        let insets = Isle.Metrics.contentInsets
        let halfGap = Isle.Metrics.cutoutWidth(topSafeAreaInset: topSafeAreaInset) / 2
        let usesSnugIslandWidth = Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) == .dynamicIsland

        // Leading content sits to the LEFT of a gap centered on the island; trailing
        // content to the RIGHT. The gap is defined relative to the view's centerX (which
        // the presenter aligns with the physical island), so the island always falls in
        // the gap and never covers the content. One-liner at the island's vertical level.
        let leading = configuration.content.leadingView ?? makeCompactContentStack()
        leading.translatesAutoresizingMaskIntoConstraints = false
        compactWrapLeadingView = leading
        addSubview(leading)

        let trailingView = configuration.content.trailingView
            ?? (configuration.content.trailingAccessory != nil ? trailingAccessoryView : nil)
        if let trailingView {
            trailingView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(trailingView)
        }

        // Hug horizontally so the black bar stays a snug shape around the island rather
        // than stretching to full width.
        setContentHuggingPriority(.required, for: .horizontal)

        // Match the island's own height so the bar coincides with the physical island
        // (a wider capsule at the same height) — no bottom "dip" from the island peeking out.
        var constraints: [NSLayoutConstraint] = [
            leading.centerYAnchor.constraint(equalTo: centerYAnchor),
            leading.trailingAnchor.constraint(equalTo: centerXAnchor, constant: -halfGap),
            heightAnchor.constraint(equalToConstant: Isle.Metrics.cutoutHeight(topSafeAreaInset: topSafeAreaInset) + 10)
        ]
        // Width is deferred when using snug island layout — the expensive
        // systemLayoutSizeFitting measurements are applied later so the
        // notification can animate in without blocking the main thread.
        if !usesSnugIslandWidth {
            // Non-island devices don't need snug sizing; no width constraint needed.
        }
        constraints.append(leading.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: insets.left))
        if let trailingView {
            constraints += [
                trailingView.centerYAnchor.constraint(equalTo: centerYAnchor),
                trailingView.leadingAnchor.constraint(greaterThanOrEqualTo: centerXAnchor, constant: halfGap),
                trailingView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right)
            ]
        } else if usesSnugIslandWidth {
            constraints.append(trailingAnchor.constraint(equalTo: centerXAnchor, constant: halfGap + insets.right))
        }
        NSLayoutConstraint.activate(constraints)
    }

    /// Measures the leading/trailing content and applies the snug width constraint for
    /// `.compactWrap` on Dynamic Island devices. Called after the animation starts so
    /// the expensive layout measurement doesn't block the main thread during presentation.
    func applyDeferredCompactWrapWidth() {
        guard Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) == .dynamicIsland else { return }
        let insets = Isle.Metrics.contentInsets
        let halfGap = Isle.Metrics.cutoutWidth(topSafeAreaInset: topSafeAreaInset) / 2
        guard let leading = compactWrapLeadingView else { return }
        let trailingView = configuration.content.trailingView
            ?? (configuration.content.trailingAccessory != nil ? trailingAccessoryView : nil)
        let leadingWidth = leading.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        let trailingWidth = trailingView?.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width ?? 0
        let sideWidth = max(leadingWidth, trailingWidth)
        let snugWidth = insets.left + sideWidth + (halfGap * 2) + sideWidth + insets.right
        let edgeInset = Isle.Metrics.compactWrapEdgeInset(topSafeAreaInset: topSafeAreaInset)
        let availableWidth = superview?.bounds.width ?? window?.bounds.width ?? 0
        let minimumWidth = insets.left + (halfGap * 2) + insets.right
        let maximumWidth = availableWidth > 0
            ? max(minimumWidth, availableWidth - (edgeInset * 2))
            : snugWidth
        let width = min(snugWidth, maximumWidth)
        compactWrapWidthConstraint?.isActive = false
        compactWrapWidthConstraint = widthAnchor.constraint(equalToConstant: width)
        compactWrapWidthConstraint?.isActive = true
    }

    private func buildCompactPill() {
        // Custom center view when set, else the built-in indicator/image/title stack.
        let centerContent = configuration.content.centerView ?? makeCompactContentStack()
        centerContent.translatesAutoresizingMaskIntoConstraints = false
        addSubview(centerContent)
        NSLayoutConstraint.activate([
            centerContent.topAnchor.constraint(equalTo: topAnchor, constant: contentTopInset),
            centerContent.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            centerContent.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerContent.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            centerContent.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            // Keep the pill at least as wide as the device's cutout so its lower half
            // never looks narrower than the island/notch it grows from.
            widthAnchor.constraint(greaterThanOrEqualToConstant: Isle.Metrics.cutoutWidth(topSafeAreaInset: topSafeAreaInset))
        ])
    }

    // MARK: - Subview factories

    private func makeActivityIndicator() -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = IsleColors.onBackground
        indicator.hidesWhenStopped = false
        indicator.startAnimating()
        return indicator
    }

    private func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.textColor = IsleColors.onBackground
        label.font = .systemFont(
            ofSize: configuration.presentation == .expanded ? 15 : 13,
            weight: .semibold
        )
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.text = configuration.content.title
        return label
    }

    private func makeSubtitleLabel() -> UILabel {
        let label = UILabel()
        label.textColor = IsleColors.secondaryText
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.numberOfLines = 2
        label.text = configuration.content.subtitle
        label.isHidden = configuration.content.subtitle == nil
        return label
    }

    private func makeLeadingImageView() -> UIImageView {
        let tint = configuration.content.leadingImageTintColor
        let imageView = UIImageView(
            image: configuration.content.leadingImage?
                .withRenderingMode(tint != nil ? .alwaysTemplate : .alwaysOriginal)
        )
        imageView.tintColor = tint
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let size: CGFloat = configuration.presentation == .expanded ? 40 : 22
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: size),
            imageView.heightAnchor.constraint(equalToConstant: size)
        ])
        if configuration.presentation == .expanded {
            imageView.layer.cornerRadius = size / 2
            imageView.layer.masksToBounds = true
        }
        return imageView
    }

    private func makeTrailingAccessoryView() -> UIView {
        switch configuration.content.trailingAccessory {
        case .image(let image, let tint):
            let imageView = UIImageView(
                image: image.withRenderingMode(tint != nil ? .alwaysTemplate : .alwaysOriginal)
            )
            imageView.tintColor = tint
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 24),
                imageView.heightAnchor.constraint(equalToConstant: 24)
            ])
            return imageView
        case .text(let text):
            if configuration.presentation != .expanded {
                return makeCompactTextView(
                    text,
                    font: .systemFont(ofSize: 13, weight: .semibold),
                    maxWidth: Isle.Metrics.compactTrailingTextMaxWidth
                )
            }
            let label = UILabel()
            label.textColor = IsleColors.onBackground
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.text = text
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            return label
        case .none:
            return UIView()
        }
    }

    // MARK: - Animation

    /// Collapsed state used for present/dismiss, tuned per cutout kind. Assumes the view
    /// is laid out (call after `layoutIfNeeded`).
    ///
    /// - Dynamic Island: the island physically morphs, so the view shrinks toward the
    ///   island's centre — content appears to collapse into the pill.
    /// - Notch / flat-top: there is no morphing hardware, so the bar slides straight up
    ///   off the top edge (a banner-style retract) and fades, which reads far more
    ///   naturally than shrinking toward a static cutout.
    private var collapsedTransform: CGAffineTransform {
        guard bounds.height > 0 else { return CGAffineTransform(scaleX: 0.2, y: 0.2) }
        switch Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) {
        case .dynamicIsland:
            // Land the shrunk shape's centre on the island's centre (view top is pinned at
            // the island top, so that centre is cutoutHeight/2 below the top).
            let scale: CGFloat = 0.2
            let cutoutHeight = Isle.Metrics.cutoutHeight(topSafeAreaInset: topSafeAreaInset)
            let shift = cutoutHeight / 2 - bounds.height / 2
            return CGAffineTransform(translationX: 0, y: shift).scaledBy(x: scale, y: scale)
        case .notch, .none:
            // Slide the whole bar up until it is fully above the screen's top edge.
            let offset = bounds.height + Isle.Metrics.shapeTopOffset(topSafeAreaInset: topSafeAreaInset)
            return CGAffineTransform(translationX: 0, y: -offset)
        }
    }

    /// Sets the pre-present state: collapsed into the island, invisible.
    public func prepareForPresentation() {
        if Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) == .dynamicIsland {
            setLayerAnchorPoint(CGPoint(x: 0.5, y: 0.5))
        } else {
            setLayerAnchorPoint(CGPoint(x: 0.5, y: 0))
        }
        alpha = 0
        transform = collapsedTransform
    }

    /// Springs the notification open, growing downward out of the island.
    public func animateIn() {
        switch Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) {
        case .dynamicIsland:
            animateIslandIn()
        case .notch, .none:
            animateTopSlideIn()
        }
    }

    private func animateIslandIn() {
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.7,
            options: [.curveEaseOut]
        ) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    private func animateTopSlideIn() {
        UIView.animate(
            withDuration: 0.34,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            self.alpha = 1
            self.transform = .identity
        } completion: { _ in
            // Top-anchored scale makes only the lower edge snap, avoiding a full
            // island-style bounce on notch devices where the top edge is fixed.
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

    /// Collapses the notification back into the island and fades it out.
    public func animateOut(completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            options: [.curveEaseIn]
        ) {
            self.alpha = 0
            self.transform = self.collapsedTransform
        } completion: { _ in
            completion()
        }
    }

    /// Lightweight attention animation for repeated notifications, such as showing the
    /// same error again while it is already visible.
    public func animateRepeatBounce() {
        let anchor = layer.anchorPoint
        setLayerAnchorPoint(CGPoint(x: 0.5, y: Isle.Metrics.cutoutKind(topSafeAreaInset: topSafeAreaInset) == .dynamicIsland ? 0.5 : 0))
        UIView.animate(
            withDuration: 0.12,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            self.transform = CGAffineTransform(scaleX: 1.035, y: 1.035)
        } completion: { _ in
            UIView.animate(
                withDuration: 0.32,
                delay: 0,
                usingSpringWithDamping: 0.62,
                initialSpringVelocity: 0.8,
                options: [.curveEaseOut]
            ) {
                self.transform = .identity
            } completion: { _ in
                self.setLayerAnchorPoint(anchor)
            }
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
#endif
