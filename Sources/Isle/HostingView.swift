#if os(iOS)
import SwiftUI
import UIKit

public class HostingView<SView: View>: UIView {

    public let view: SView

    public init(customView: SView) {
        view = customView

        super.init(frame: .zero)

        let host = UIHostingController(rootView: customView)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        parentViewController.flatMap { $0.addChild(host) }
        addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        parentViewController.flatMap(host.didMove)
        host.view.layoutIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

extension UIView {

    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder?.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }

        return nil
    }
}
#endif
