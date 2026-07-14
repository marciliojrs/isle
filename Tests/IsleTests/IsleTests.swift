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
        #expect(config.autoDismissAfter == 3)
        #expect(config.allowsSwipeToDismiss == true)
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
}
#endif
