#if os(iOS)
import UIKit

/// A text label that scrolls horizontally (marquee) when its content is wider
/// than the available space. Use as a `leadingView` or `trailingView` in
/// `Isle.Configuration` to get auto-scrolling text in compact notifications.
///
/// When the text fits within the view's bounds, it stays static. Once the view
/// is laid out wider than the text needs, it pauses. When the text overflows,
/// it scrolls from right to left, then resets and pauses before scrolling again.
@MainActor
public final class IsleMarqueeView: UIView {

    /// Style configuration for the marquee text.
    public struct Style {
        public var font: UIFont
        public var textColor: UIColor
        /// Points per second the text scrolls at.
        public var speed: CGFloat
        /// Seconds to pause at each end before scrolling resumes.
        public var pauseDuration: TimeInterval
        /// Gap between the end of one scroll and the restart (visual spacing when
        /// the text wraps around). Defaults to 40pt.
        public var gap: CGFloat

        public init(
            font: UIFont = .systemFont(ofSize: 15, weight: .semibold),
            textColor: UIColor = .white,
            speed: CGFloat = 40,
            pauseDuration: TimeInterval = 1.5,
            gap: CGFloat = 40
        ) {
            self.font = font
            self.textColor = textColor
            self.speed = speed
            self.pauseDuration = pauseDuration
            self.gap = gap
        }
    }

    // MARK: - Public

    public var text: String? {
        didSet { label.text = text; invalidateIntrinsicContentSize(); restartIfVisible() }
    }

    public var style: Style {
        didSet { applyStyle() }
    }

    /// Maximum width the view will report as its intrinsic content size.
    /// When the text is wider, Auto Layout compresses the view to this width
    /// and the scroll animation kicks in. Set this to match the available slot
    /// width in the notification (e.g. half the island width minus insets).
    public var maxWidth: CGFloat = 120 {
        didSet { invalidateIntrinsicContentSize() }
    }

    // MARK: - Private

    private let label = UILabel()
    private let clipView = UIView()
    private var displayLink: CADisplayLink?
    private var progress: CGFloat = 0
    private var phase: Phase = .paused
    private var lastTimestamp: CFTimeInterval = 0
    private var textWidth: CGFloat = 0
    private var didLayoutForScroll = false

    private enum Phase { case scrolling, paused }

    // MARK: - Init

    public init(text: String? = nil, style: Style = .init()) {
        self.text = text
        self.style = style
        super.init(frame: .zero)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { displayLink?.invalidate() }

    // MARK: - Layout

    /// Intrinsic width is capped at `maxWidth` so Auto Layout compresses the view
    /// instead of expanding it to fit the full text. The scroll check in
    /// `layoutSubviews` then sees overflow and starts the animation.
    public override var intrinsicContentSize: CGSize {
        let h = style.font.lineHeight
        guard let text, !text.isEmpty else { return CGSize(width: 0, height: h) }
        let w = (text as NSString).size(withAttributes: [.font: style.font]).width
        return CGSize(width: min(w, maxWidth), height: h)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        clipView.frame = bounds

        textWidth = (label.text as NSString?)?.size(withAttributes: [.font: style.font]).width
            ?? intrinsicContentSize.width
        let shouldScroll = bounds.width > 0 && textWidth > bounds.width + 1

        if shouldScroll {
            label.frame = CGRect(x: 0, y: 0, width: textWidth, height: bounds.height)
            if !didLayoutForScroll {
                didLayoutForScroll = true
                progress = 0
                phase = .paused
                lastTimestamp = 0
                startDisplayLink()
            }
            updateLabelPosition()
        } else {
            stopDisplayLink()
            phase = .paused
            label.transform = .identity
            label.frame = clipView.bounds
            didLayoutForScroll = false
        }
    }

    // MARK: - Configuration

    private func configure() {
        clipsToBounds = true
        clipView.clipsToBounds = true
        addSubview(clipView)

        label.numberOfLines = 1
        label.setContentHuggingPriority(.required, for: .horizontal)
        // Low compression resistance lets Auto Layout compress the view to available
        // space so the text overflows and the scroll check in layoutSubviews triggers.
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        clipView.addSubview(label)

        applyStyle()
    }

    private func applyStyle() {
        label.font = style.font
        label.textColor = style.textColor
        label.text = text
        invalidateIntrinsicContentSize()
    }

    private func restartIfVisible() {
        guard bounds.width > 0 else { return }
        textWidth = (label.text as NSString?)?.size(withAttributes: [.font: style.font]).width
            ?? intrinsicContentSize.width
        if textWidth > bounds.width + 1 {
            progress = 0
            phase = .paused
            lastTimestamp = 0
            didLayoutForScroll = true
            startDisplayLink()
        }
    }

    // MARK: - Animation

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        let dt = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp

        switch phase {
        case .paused:
            phase = .scrolling
        case .scrolling:
            let travel = textWidth + style.gap
            progress += CGFloat(dt) * style.speed / travel
            if progress >= 1 {
                progress = 0
                phase = .paused
                lastTimestamp = link.timestamp
            }
        }

        updateLabelPosition()
    }

    private func updateLabelPosition() {
        let travel = textWidth + style.gap
        let offset = progress * travel
        let startX = bounds.width
        label.frame.origin.x = startX - offset
        label.frame.size.width = textWidth
        label.frame.size.height = bounds.height
    }
}
#endif
