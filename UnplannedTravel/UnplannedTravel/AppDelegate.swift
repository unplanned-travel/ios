import UIKit
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {
    /// Called when the user accepts a CloudKit share invitation (email link or AirDrop).
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        NotificationCenter.default.post(
            name: .cloudKitShareAccepted,
            object: cloudKitShareMetadata
        )
    }
}

extension Notification.Name {
    static let cloudKitShareAccepted = Notification.Name("cloudKitShareAccepted")
}
