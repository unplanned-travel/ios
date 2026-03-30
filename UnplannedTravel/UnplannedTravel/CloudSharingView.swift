import SwiftUI
import CloudKit
import UIKit

/// Wraps UICloudSharingController so it can be presented as a SwiftUI sheet.
/// UICloudSharingController must be presented modally from a plain UIViewController;
/// embedding it directly as the representable causes a blank page.
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

    /// Saves the CKShare first, then presents UICloudSharingController(share:container:).
    /// Using the preparationHandler form causes "No optionsGroups" errors because CloudKit
    /// expects the share to NOT be pre-saved when that initializer is used.
    final class ContainerVC: UIViewController {
        weak var coordinator: Coordinator?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let coordinator, !coordinator.presented else { return }
            coordinator.presented = true

            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let (_, share) = try await coordinator.store.prepararShare(para: coordinator.plan)
                    let container = CKContainer(identifier: CloudKitStore.containerID)
                    let csc = UICloudSharingController(share: share, container: container)
                    csc.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
                    csc.delegate = coordinator
                    self.present(csc, animated: true)
                } catch {
                    print("[CloudKit] prepararShare falló: \(error.localizedDescription)")
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
