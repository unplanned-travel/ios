import SwiftUI
import CloudKit
import UIKit

/// Zero-size UIViewControllerRepresentable that presents UICloudSharingController
/// directly on the top-most UIViewController — no SwiftUI sheet involved,
/// so there is only one presentation/dismissal animation.
struct CloudSharingView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let plan: Plan
    @Environment(CloudKitStore.self) var store

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, plan: plan, setPresented: { isPresented = $0 })
    }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.store = store        // refresh in case environment changes

        if isPresented && !coordinator.presented {
            coordinator.presented = true
            Task { @MainActor in
                guard let topVC = UIViewController.top() else {
                    coordinator.close(); return
                }
                do {
                    let csc: UICloudSharingController
                    // Always pre-save the share then use init(share:container:).
                    // UICloudSharingController(preparationHandler:) is deprecated since iOS 17.
                    if coordinator.store.tieneShareLocal(plan: plan),
                       let (share, container) = try await coordinator.store.fetchShareExistente(para: plan) {
                        csc = UICloudSharingController(share: share, container: container)
                    } else {
                        let (share, container) = try await coordinator.store.crearNuevoShare(para: plan)
                        csc = UICloudSharingController(share: share, container: container)
                    }
                    csc.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
                    csc.delegate = coordinator
                    topVC.present(csc, animated: true)
                    // Catch dismissal via "Done" which doesn't trigger any delegate method.
                    csc.presentationController?.delegate = coordinator
                } catch {
                    print("[CloudKit] Error preparando share: \(error.localizedDescription)")
                    coordinator.close()
                }
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICloudSharingControllerDelegate, UIAdaptivePresentationControllerDelegate {
        var store: CloudKitStore
        let plan: Plan
        private let setPresented: (Bool) -> Void
        var presented = false

        init(store: CloudKitStore, plan: Plan, setPresented: @escaping (Bool) -> Void) {
            self.store = store
            self.plan = plan
            self.setPresented = setPresented
        }

        func close() {
            presented = false
            setPresented(false)
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            plan.titulo.isEmpty ? nil : plan.titulo
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("[CloudKit] Error al compartir: \(error.localizedDescription)")
            close()
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { close() }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { close() }

        // Called when the user dismisses the sheet without making changes (e.g. "Done").
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            close()
        }
    }
}

private extension UIViewController {
    /// Returns the topmost presented UIViewController in the key window.
    static func top() -> UIViewController? {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
