#if os(iOS)
import UIKit

extension Isle {
    static func makeConfirmationView(
        title: String,
        message: String?,
        confirmTitle: String,
        cancelTitle: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = IsleColors.onBackground
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = IsleColors.secondaryText
        messageLabel.font = .systemFont(ofSize: 13, weight: .regular)
        messageLabel.numberOfLines = 3
        messageLabel.textAlignment = .center
        messageLabel.isHidden = message == nil

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 4

        let cancelButton = makeConfirmationButton(title: cancelTitle, style: .secondary, action: onCancel)
        let confirmButton = makeConfirmationButton(title: confirmTitle, style: .primary, action: onConfirm)

        let buttonStack = UIStackView(arrangedSubviews: [cancelButton, confirmButton])
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 8

        let stack = UIStackView(arrangedSubviews: [textStack, buttonStack])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            buttonStack.heightAnchor.constraint(equalToConstant: 36),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])

        return container
    }

    private enum ConfirmationButtonStyle {
        case primary
        case secondary
    }

    private static func makeConfirmationButton(
        title: String,
        style: ConfirmationButtonStyle,
        action: @escaping () -> Void
    ) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = style == .primary
            ? IsleColors.onBackground
            : IsleColors.surface
        configuration.baseForegroundColor = style == .primary
            ? IsleColors.background
            : IsleColors.onBackground
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)

        let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in
            action()
        })
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.accessibilityLabel = title
        return button
    }
}
#endif
