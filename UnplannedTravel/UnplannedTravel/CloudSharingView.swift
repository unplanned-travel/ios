import SwiftUI
import CloudKit
import UIKit

/// Zero-size UIViewControllerRepresentable that presents UICloudSharingController
/// directly on the top-most UIViewController — no SwiftUI sheet involved,
/// so there is only one presentation/dismissal animation.
struct CloudSharingView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let plan: Plan
    var onError: ((String) -> Void)? = nil
    @Environment(CloudKitStore.self) var store

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, plan: plan, setPresented: { isPresented = $0 }, onError: onError)
    }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.store = store

        if isPresented && !coordinator.presented {
            coordinator.presented = true
            Task { @MainActor in
                guard let topVC = UIViewController.top() else {
                    coordinator.close(); return
                }
                do {
                    if coordinator.store.tieneShareLocal(plan: plan),
                       let (share, container) = try await coordinator.store.fetchShareExistente(para: plan) {
                        // Existing share — show management UI (CSC)
                        let csc = UICloudSharingController(share: share, container: container)
                        csc.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
                        csc.delegate = coordinator

                        let observer = DismissObserverVC { [weak coordinator] in
                            coordinator?.close()
                        }
                        csc.addChild(observer)
                        observer.view.frame = .zero
                        csc.view.addSubview(observer.view)
                        observer.didMove(toParent: csc)

                        topVC.present(csc, animated: true)
                    } else {
                        // New share — create it and show activity VC so the link is immediately copyable.
                        let (share, container) = try await coordinator.store.crearNuevoShare(para: plan)

                        guard let url = share.url else {
                            throw NSError(domain: "CloudKitStore", code: 3,
                                          userInfo: [NSLocalizedDescriptionKey: "Share sin URL tras guardarse"])
                        }

                        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        activityVC.completionWithItemsHandler = { [weak coordinator] _, _, _, _ in
                            coordinator?.close()
                        }
                        if let popover = activityVC.popoverPresentationController {
                            popover.sourceView = topVC.view
                            popover.sourceRect = CGRect(x: topVC.view.bounds.midX,
                                                        y: topVC.view.bounds.midY,
                                                        width: 0, height: 0)
                            popover.permittedArrowDirections = []
                        }

                        // Also set up CSC in background so the share is properly configured.
                        let csc = UICloudSharingController(share: share, container: container)
                        csc.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
                        csc.delegate = coordinator

                        topVC.present(activityVC, animated: true)
                    }
                } catch {
                    print("[CloudKit] ❌ Error preparando share: \(error)")
                    coordinator.onError?(error.localizedDescription)
                    coordinator.close()
                }
            }
        }
    }

    // MARK: - Dismiss observer

    /// Zero-size child VC added to UICloudSharingController.
    /// viewDidDisappear fires whenever the parent is dismissed — including
    /// programmatic dismissal from the Done button.
    private final class DismissObserverVC: UIViewController {
        private let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            // parent?.isBeingDismissed covers both interactive and programmatic dismissal.
            if parent?.isBeingDismissed == true {
                onDismiss()
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var store: CloudKitStore
        let plan: Plan
        private let setPresented: (Bool) -> Void
        let onError: ((String) -> Void)?
        var presented = false
        var errorMessage: String?

        init(store: CloudKitStore, plan: Plan, setPresented: @escaping (Bool) -> Void, onError: ((String) -> Void)?) {
            self.store = store
            self.plan = plan
            self.setPresented = setPresented
            self.onError = onError
        }

        func close() {
            guard presented else { return }
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
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task { @MainActor in
                await store.actualizarTrasDetenerShare(para: plan)
            }
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
