import SwiftUI
import CloudKit

// MARK: - Presentation wrapper

struct SharePresentation: Identifiable {
    let id = UUID()
    let share: CKShare
}

// MARK: - Main view

struct ShareManagementView: View {
    let plan: Plan
    @EnvironmentObject private var store: CloudKitStore
    @Environment(\.dismiss) private var dismiss

    // CKShare is a class; changeToken forces SwiftUI to re-read it after mutations.
    @State private var share: CKShare
    @State private var changeToken = UUID()

    @State private var enlaceCopied = false
    @State private var mostrarAgregarPersona = false
    @State private var confirmarDetener = false
    @State private var guardando = false
    @State private var error: String?

    init(plan: Plan, share: CKShare) {
        self.plan = plan
        _share = State(initialValue: share)
    }

    private var esPropietario: Bool {
        share.currentUserParticipant?.role == .owner
    }

    private var participantes: [CKShare.Participant] {
        let _ = changeToken
        return share.participants.filter { $0.acceptanceStatus != .removed }
    }

    var body: some View {
        NavigationStack {
            Form {
                linkSection
                if esPropietario { accesoSection }
                participantesSection
                if esPropietario { detenerSection }
            }
            .navigationTitle(plan.titulo.isEmpty ? String(localized: "share.title") : plan.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if guardando {
                        ProgressView()
                    } else {
                        Button(String(localized: "share.done")) { dismiss() }
                    }
                }
            }
            .disabled(guardando)
            .sheet(isPresented: $mostrarAgregarPersona) {
                AgregarParticipanteView(share: share) { updated in
                    share = updated
                    changeToken = UUID()
                }
            }
            .alert(String(localized: "share.stopSharing.confirm.title"), isPresented: $confirmarDetener) {
                Button(String(localized: "share.stopSharing"), role: .destructive) { detener() }
                Button(String(localized: "share.cancel"), role: .cancel) {}
            } message: {
                Text("share.stopSharing.confirm.message")
            }
            .alert(String(localized: "share.error.title"), isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
        }
    }

    // MARK: - Sections

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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            enlaceCopied = false
                        }
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

    @ViewBuilder private var accesoSection: some View {
        Section(String(localized: "share.section.access")) {
            Picker(String(localized: "share.access.label"), selection: permisoPublicoBinding) {
                Text(String(localized: "share.access.invited"))
                    .tag(CKShare.ParticipantPermission.none)
                Text(String(localized: "share.access.anyoneReadOnly"))
                    .tag(CKShare.ParticipantPermission.readOnly)
                Text(String(localized: "share.access.anyoneReadWrite"))
                    .tag(CKShare.ParticipantPermission.readWrite)
            }
        }
    }

    private var permisoPublicoBinding: Binding<CKShare.ParticipantPermission> {
        Binding(
            get: { share.publicPermission },
            set: { actualizarAcceso($0) }
        )
    }

    @ViewBuilder private var participantesSection: some View {
        Section(String(localized: "share.section.participants")) {
            ForEach(participantes, id: \.userIdentity.userRecordID?.recordName) { p in
                participanteRow(p)
                    .deleteDisabled(!esPropietario || p.role == .owner)
            }
            .onDelete { offsets in
                if esPropietario { eliminarParticipantes(offsets) }
            }

            if esPropietario {
                Button {
                    mostrarAgregarPersona = true
                } label: {
                    Label(String(localized: "share.addPeople"), systemImage: "person.badge.plus")
                }
            }
        }
    }

    private func participanteRow(_ p: CKShare.Participant) -> some View {
        let isOwner = p.role == .owner
        return HStack(spacing: 12) {
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

    @ViewBuilder private var detenerSection: some View {
        Section {
            Button(role: .destructive) {
                confirmarDetener = true
            } label: {
                Text(String(localized: "share.stopSharing"))
            }
        }
    }

    // MARK: - Actions

    private func actualizarAcceso(_ permiso: CKShare.ParticipantPermission) {
        guardando = true
        Task {
            do {
                share = try await store.actualizarAccesoPublico(permiso, en: share)
                changeToken = UUID()
            } catch {
                self.error = error.localizedDescription
            }
            guardando = false
        }
    }

    private func eliminarParticipantes(_ offsets: IndexSet) {
        let targets = offsets.compactMap { i -> CKShare.Participant? in
            let p = participantes[i]
            return p.role == .owner ? nil : p
        }
        guard !targets.isEmpty else { return }
        guardando = true
        Task {
            do {
                var updated = share
                for p in targets {
                    updated = try await store.eliminarParticipante(p, de: updated)
                }
                share = updated
                changeToken = UUID()
            } catch {
                self.error = error.localizedDescription
            }
            guardando = false
        }
    }

    private func detener() {
        guardando = true
        Task {
            do {
                try await store.detenerShare(para: plan)
                dismiss()
            } catch {
                self.error = error.localizedDescription
                guardando = false
            }
        }
    }

    // MARK: - Helpers

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
        case .owner: return String(localized: "share.role.owner")
        default:
            switch p.permission {
            case .readWrite: return String(localized: "share.role.readWrite")
            default:         return String(localized: "share.role.readOnly")
            }
        }
    }
}

// MARK: - Add participant sheet

struct AgregarParticipanteView: View {
    let share: CKShare
    let onAdded: (CKShare) -> Void
    @EnvironmentObject private var store: CloudKitStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var permiso: CKShare.ParticipantPermission = .readWrite
    @State private var buscando = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "share.addPeople.email"), text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text(String(localized: "share.addPeople.footer"))
                }

                Section(String(localized: "share.section.permission")) {
                    Picker(String(localized: "share.permission.label"), selection: $permiso) {
                        Text(String(localized: "share.role.readOnly"))
                            .tag(CKShare.ParticipantPermission.readOnly)
                        Text(String(localized: "share.role.readWrite"))
                            .tag(CKShare.ParticipantPermission.readWrite)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(String(localized: "share.addPeople"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "share.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if buscando {
                        ProgressView()
                    } else {
                        Button(String(localized: "share.addPeople.add")) { agregar() }
                            .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .disabled(buscando)
            .alert(String(localized: "share.error.title"), isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
        }
    }

    private func agregar() {
        let emailClean = email.trimmingCharacters(in: .whitespaces)
        guard !emailClean.isEmpty else { return }
        buscando = true
        Task {
            do {
                let updated = try await store.agregarParticipante(email: emailClean, permiso: permiso, a: share)
                onAdded(updated)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            buscando = false
        }
    }
}
