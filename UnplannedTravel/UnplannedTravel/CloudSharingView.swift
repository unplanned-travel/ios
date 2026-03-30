import SwiftUI
import CloudKit
import UIKit

/// Wraps UICloudSharingController so it can be presented as a SwiftUI sheet.
/// UICloudSharingController must be presented from a real UIViewController in viewDidAppear
/// to have a valid window, otherwise it renders blank.
struct CloudSharingView: UIViewControllerRepresentable {
    @Environment(CloudKitStore.self) var store
    let plan: Plan
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(store: store, plan: plan, dismiss: dismiss) }

    func makeUIViewController(context: Context) -> ContainerVC {
        let vc = ContainerVC()
        vc.coordinator = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ContainerVC, context: Context) {}

    // MARK: - Container VC

    final class ContainerVC: UIViewController {
        weak var coordinator: Coordinator?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let coordinator, !coordinator.presented else { return }
            coordinator.presented = true

            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let csc: UICloudSharingController
                    if coordinator.store.tieneShareLocal(plan: coordinator.plan) {
                        // Share already exists — use management initializer.
                        guard let (share, container) = try await coordinator.store.fetchShareExistente(para: coordinator.plan) else {
                            coordinator.dismiss(); return
                        }
                        csc = UICloudSharingController(share: share, container: container)
                    } else {
                        // No share yet — create it inside the preparationHandler.
                        csc = UICloudSharingController { [weak coordinator] _, completion in
                            guard let coordinator else { return }
                            Task { @MainActor in
                                do {
                                    let (share, container) = try await coordinator.store.crearNuevoShare(para: coordinator.plan)
                                    completion(share, container, nil)
                                } catch {
                                    completion(nil, nil, error)
                                }
                            }
                        }
                    }
                    csc.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
                    csc.delegate = coordinator
                    self.present(csc, animated: true)
                } catch {
                    print("[CloudKit] Error preparando share: \(error.localizedDescription)")
                    coordinator.dismiss()
                }
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let store: CloudKitStore
        let plan: Plan
        let dismiss: DismissAction
        var presented = false

        init(store: CloudKitStore, plan: Plan, dismiss: DismissAction) {
            self.store = store
            self.plan = plan
            self.dismiss = dismiss
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("[CloudKit] Error al compartir: \(error.localizedDescription)")
            dismiss()
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            plan.titulo.isEmpty ? nil : plan.titulo
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { dismiss() }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { dismiss() }
    }
}
