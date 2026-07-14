#if os(iOS)
import SwiftUI

@available(iOS 15.0, *)
public extension View {
    /// Presents an Isle notification while `isPresented` is `true`. When the
    /// notification ends on its own (auto-dismiss timer, swipe, or replacement),
    /// `isPresented` is set back to `false`.
    func isleNotification(
        isPresented: Binding<Bool>,
        _ configuration: @autoclosure @escaping () -> Isle.Configuration
    ) -> some View {
        modifier(IsleBoolModifier(isPresented: isPresented, configuration: configuration))
    }

    /// Presents an Isle notification whenever `item` becomes non-`nil`, building the
    /// configuration from the unwrapped value. `item` is reset to `nil` on dismissal.
    func isleNotification<Item>(
        item: Binding<Item?>,
        _ configuration: @escaping (Item) -> Isle.Configuration
    ) -> some View {
        modifier(IsleItemModifier(item: item, configuration: configuration))
    }
}

@available(iOS 15.0, *)
private struct IsleBoolModifier: ViewModifier {
    @Binding var isPresented: Bool
    let configuration: () -> Isle.Configuration
    @State private var token: IsleToken?

    func body(content: Content) -> some View {
        content.task(id: isPresented) {
            if isPresented {
                token = IsleNotificationCenter.shared.show(configuration()) {
                    isPresented = false
                    token = nil
                }
            } else {
                token?.dismiss()
                token = nil
            }
        }
    }
}

@available(iOS 15.0, *)
private struct IsleItemModifier<Item>: ViewModifier {
    @Binding var item: Item?
    let configuration: (Item) -> Isle.Configuration
    @State private var token: IsleToken?

    func body(content: Content) -> some View {
        content.task(id: item != nil) {
            if let value = item {
                token = IsleNotificationCenter.shared.show(configuration(value)) {
                    item = nil
                    token = nil
                }
            } else {
                token?.dismiss()
                token = nil
            }
        }
    }
}
#endif
