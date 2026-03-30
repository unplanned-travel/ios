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

    /// A plain UIViewController that presents UICloudSharingController once it appears.
    final class ContainerVC: UIViewController {
        weak var coordinator: Coordinator?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            coordinator?.presentSharingController(from: self)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let store: CloudKitStore
        let plan: Plan
        let dismiss: DismissAction
        private var presented = false

        init(store: CloudKitStore, plan: Plan, dismiss: DismissAction) {
            self.store = store
            self.plan = plan
            self.dismiss = dismiss
        }

        func presentSharingController(from vc: UIViewController) {
            guard !presented else { return }
            presented = true

            let csc = UICloudSharingController { [weak self] _, completion in
                guard let self else { return }
                Task { @MainActor in
                    do {
                        let (_, share) = try await self.store.prepararShare(para: self.plan)
                        let container = CKContainer(identifier: CloudKitStore.containerID)
                        completion(share, container, nil)
                    } catch {
                        completion(nil, nil, error)
                    }
                }
            }
            csc.availablePermissions = [.allowReadOnly, .allowReadWrite, .allowPrivate]
            csc.delegate = self
            vc.present(csc, animated: true)
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
