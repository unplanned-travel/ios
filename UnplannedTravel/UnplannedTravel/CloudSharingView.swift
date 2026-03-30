import SwiftUI
import CloudKit
import UIKit

/// Wraps UICloudSharingController so it can be presented as a SwiftUI sheet.
struct CloudSharingView: UIViewControllerRepresentable {
    @Environment(CloudKitStore.self) var store
    let plan: Plan

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController { _, completion in
            Task { @MainActor in
                do {
                    let (record, share) = try await store.prepararShare(para: plan)
                    let container = CKContainer(identifier: CloudKitStore.containerID)
                    completion(share, container, nil)
                    _ = record
                } catch {
                    completion(nil, nil, error)
                }
            }
        }
        controller.availablePermissions = [.allowReadOnly, .allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("[CloudKit] Error al compartir: \(error.localizedDescription)")
            dismiss()
        }

        func itemTitle(for csc: UICloudSharingController) -> String? { nil }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { dismiss() }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { dismiss() }
    }
}
