import SwiftUI
import CloudKit
import UIKit

// MARK: - SwiftUI wrapper

struct SharePresentation: Identifiable {
    let id = UUID()
    let share: CKShare
}

struct DirectSharingView: UIViewControllerRepresentable {
    let plan: Plan
    let share: CKShare
    let container: CKContainer
    var onDismiss: () -> Void
    var onStopSharing: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss, onStopSharing: onStopSharing)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let csc = UICloudSharingController(share: share, container: container)
        csc.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        csc.delegate = context.coordinator

        let title = plan.titulo.isEmpty
            ? NSLocalizedString("share.title", comment: "")
            : plan.titulo

        let root = SharingContainerVC(share: share, csc: csc, title: title) {
            context.coordinator.onDismiss()
        }

        return UINavigationController(rootViewController: root)
    }

    func updateUIViewController(_ vc: UINavigationController, context: Context) {}

    // MARK: Coordinator

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onDismiss: () -> Void
        let onStopSharing: () -> Void

        init(onDismiss: @escaping () -> Void, onStopSharing: @escaping () -> Void) {
            self.onDismiss = onDismiss
            self.onStopSharing = onStopSharing
        }

        func itemTitle(for csc: UICloudSharingController) -> String? { nil }

        func cloudSharingController(_ csc: UICloudSharingController,
                                    failedToSaveShareWithError error: Error) {
            print("[CloudKit] Share error: \(error.localizedDescription)")
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onStopSharing()
            onDismiss()
        }
    }
}

// MARK: - Container UIViewController

/// Embeds UICloudSharingController with a compact link bar above it.
final class SharingContainerVC: UIViewController {
    private let share: CKShare
    private let csc: UICloudSharingController
    private let onDone: () -> Void

    init(share: CKShare, csc: UICloudSharingController,
         title: String, onDone: @escaping () -> Void) {
        self.share = share
        self.csc = csc
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )

        // Embed UICloudSharingController as child
        addChild(csc)
        view.addSubview(csc.view)
        csc.view.translatesAutoresizingMaskIntoConstraints = false
        csc.didMove(toParent: self)

        if let url = share.url {
            let linkBar = makeLinkBar(url: url)
            view.addSubview(linkBar)
            linkBar.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                linkBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                linkBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                linkBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

                csc.view.topAnchor.constraint(equalTo: linkBar.bottomAnchor),
                csc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                csc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                csc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                csc.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                csc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                csc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                csc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }
    }

    @objc private func doneTapped() { onDone() }

    // MARK: - Link bar

    private func makeLinkBar(url: URL) -> UIView {
        let bar = UIView()
        bar.backgroundColor = .secondarySystemGroupedBackground

        let label = UILabel()
        label.text = url.absoluteString
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let copyBtn = UIButton(type: .system)
        copyBtn.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyBtn.addTarget(self, action: #selector(copyLink), for: .touchUpInside)
        copyBtn.accessibilityLabel = NSLocalizedString("share.alert.copy", comment: "")
        copyBtn.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [label, copyBtn])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)

        let sep = UIView()
        sep.backgroundColor = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(sep)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bar.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: sep.topAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),

            sep.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            sep.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        return bar
    }

    @objc private func copyLink() {
        guard let url = share.url else { return }
        UIPasteboard.general.url = url

        // Brief icon swap as visual feedback
        guard let btn = (view.subviews
            .compactMap { $0 as? UIStackView }.first?
            .arrangedSubviews.last as? UIButton) else { return }
        btn.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
        btn.tintColor = .systemGreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            btn.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
            btn.tintColor = btn.superview?.tintColor
        }
    }
}
