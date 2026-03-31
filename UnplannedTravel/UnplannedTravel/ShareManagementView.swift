import SwiftUI
import CloudKit

struct SharePresentation: Identifiable {
    let id = UUID()
    let share: CKShare
}

struct ShareManagementView: View {
    let plan: Plan
    let share: CKShare
    @EnvironmentObject var store: CloudKitStore
    @Environment(\.dismiss) var dismiss

    @State private var enlaceCopied = false
    @State private var confirmarDetener = false
    @State private var deteniendo = false
    @State private var errorDetener: String?

    private var esPropietario: Bool {
        share.currentUserParticipant?.role == .owner
    }

    var body: some View {
        NavigationStack {
            List {
                linkSection
                participantsSection
                if esPropietario { stopSharingSection }
            }
            .navigationTitle(plan.titulo.isEmpty ? String(localized: "share.title") : plan.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "share.done")) { dismiss() }
                }
            }
            .alert(String(localized: "share.stopSharing.confirm.title"), isPresented: $confirmarDetener) {
                Button(String(localized: "share.stopSharing"), role: .destructive) {
                    Task {
                        deteniendo = true
                        do {
                            try await store.detenerShare(para: plan)
                            dismiss()
                        } catch {
                            errorDetener = error.localizedDescription
                            deteniendo = false
                        }
                    }
                }
                Button(String(localized: "share.cancel"), role: .cancel) {}
            } message: {
                Text("share.stopSharing.confirm.message")
            }
            .alert(String(localized: "share.error.title"), isPresented: .init(
                get: { errorDetener != nil },
                set: { if !$0 { errorDetener = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorDetener ?? "")
            }
        }
    }

    @ViewBuilder private var linkSection: some View {
        if let url = share.url {
            Section(String(localized: "share.section.link")) {
                HStack {
                    Text(url.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        UIPasteboard.general.url = url
                        enlaceCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { enlaceCopied = false }
                    } label: {
                        Image(systemName: enlaceCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundStyle(enlaceCopied ? .green : .accentColor)
                            .animation(.default, value: enlaceCopied)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var participantsSection: some View {
        let participants = share.participants.filter { $0.acceptanceStatus != .removed }
        if !participants.isEmpty {
            Section(String(localized: "share.section.participants")) {
                ForEach(participants, id: \.userIdentity.userRecordID?.recordName) { p in
                    participantRow(p)
                }
            }
        }
    }

    private func participantRow(_ p: CKShare.Participant) -> some View {
        let isOwner = p.role == .owner
        return HStack {
            Image(systemName: isOwner ? "person.crop.circle.fill" : "person.crop.circle")
                .foregroundStyle(isOwner ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(nombreParticipante(p))
                Text(rolParticipante(p))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var stopSharingSection: some View {
        Section {
            Button(role: .destructive) {
                confirmarDetener = true
            } label: {
                HStack {
                    if deteniendo { ProgressView().padding(.trailing, 4) }
                    Text("share.stopSharing")
                }
            }
            .disabled(deteniendo)
        }
    }

    private func nombreParticipante(_ p: CKShare.Participant) -> String {
        if let components = p.userIdentity.nameComponents {
            return PersonNameComponentsFormatter.localizedString(from: components, style: .default)
        }
        return p.userIdentity.lookupInfo?.emailAddress
            ?? p.userIdentity.lookupInfo?.phoneNumber
            ?? String(localized: "share.participant.unknown")
    }

    private func rolParticipante(_ p: CKShare.Participant) -> String {
        switch p.role {
        case .owner:
            return String(localized: "share.role.owner")
        default:
            switch p.permission {
            case .readWrite: return String(localized: "share.role.readWrite")
            default:         return String(localized: "share.role.readOnly")
            }
        }
    }
}
