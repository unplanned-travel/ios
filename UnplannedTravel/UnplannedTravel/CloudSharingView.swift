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
                    let share: CKShare
                    let container: CKContainer

                    if coordinator.store.tieneShareLocal(plan: plan),
                       let existing = try await coordinator.store.fetchShareExistente(para: plan) {
                        (share, container) = existing
                    } else {
                        (share, container) = try await coordinator.store.crearNuevoShare(para: plan)
                    }

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

                    if let url = share.url {
                        // UICloudSharingController doesn't display the URL directly —
                        // show an alert first so the user can copy the link immediately.
                        let alert = UIAlertController(
                            title: NSLocalizedString("share.alert.title", comment: ""),
                            message: url.absoluteString,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(
                            title: NSLocalizedString("share.alert.copy", comment: ""),
                            style: .default
                        ) { [weak coordinator] _ in
                            UIPasteboard.general.url = url
                            coordinator?.close()
                        })
                        alert.addAction(UIAlertAction(
                            title: NSLocalizedString("share.alert.manage", comment: ""),
                            style: .default
                        ) { [weak topVC] _ in
                            topVC?.present(csc, animated: true)
                        })
                        alert.addAction(UIAlertAction(
                            title: NSLocalizedString("share.alert.close", comment: ""),
                            style: .cancel
                        ) { [weak coordinator] _ in
                            coordinator?.close()
                        })
                        topVC.present(alert, animated: true)
                    } else {
                        topVC.present(csc, animated: true)
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
