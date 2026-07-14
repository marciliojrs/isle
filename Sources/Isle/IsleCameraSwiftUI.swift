#if os(iOS)
import SwiftUI
import UIKit

@available(iOS 15.0, *)
public extension View {
    func isleCamera(
        isPresented: Binding<Bool>,
        configuration: Isle.CameraConfiguration = Isle.CameraConfiguration(),
        onCapture: @escaping (UIImage) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> some View {
        modifier(
            IsleCameraModifier(
                isPresented: isPresented,
                configuration: configuration,
                onCapture: onCapture,
                onError: onError
            )
        )
    }
}

@available(iOS 15.0, *)
private struct IsleCameraModifier: ViewModifier {
    @Binding var isPresented: Bool
    let configuration: Isle.CameraConfiguration
    let onCapture: (UIImage) -> Void
    let onError: ((Error) -> Void)?
    @State private var token: IsleCameraToken?

    func body(content: Content) -> some View {
        content.task(id: isPresented) {
            if isPresented {
                token = IsleCameraCenter.shared.showCamera(
                    configuration: configuration,
                    onCapture: onCapture,
                    onDismiss: {
                        isPresented = false
                        token = nil
                    },
                    onError: onError
                )
            } else {
                token?.dismiss()
                token = nil
            }
        }
    }
}
#endif
