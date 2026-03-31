import SwiftUI
import CloudKit

struct PlanesView: View {
    @Environment(CloudKitStore.self) var store

    @State private var mostrarNuevoPlan = false
    @State private var urlPDF: URL?
    @State private var mostrarCompartir = false
    @State private var errorImport: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.planes) { plan in
                    NavigationLink(destination: PlanDetailView(planID: plan.id)) {
                        PlanRowView(plan: plan)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            urlPDF = plan.generarPDF(etapas: store.etapasOrdenadas(para: plan.id))
                            mostrarCompartir = true
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                        .disabled(store.etapasPorPlan[plan.id]?.isEmpty ?? true)
                    }
                }
                .onDelete { offsets in
                    let targets = offsets.map { store.planes[$0] }
                    Task {
                        for plan in targets {
                            try? await store.eliminarPlan(plan)
                        }
                    }
                }
            }
            .navigationTitle("Unplanned")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !store.planes.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { mostrarNuevoPlan = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if !store.cuentaDisponible, let msg = store.errorMensaje {
                    ContentUnavailableView(
                        "iCloud Required",
                        systemImage: "icloud.slash",
                        description: Text(msg)
                    )
                } else if store.planes.isEmpty && !store.cargando {
                    ContentUnavailableView(
                        "No plans",
                        systemImage: "map",
                        description: Text("Add your first trip with the + button")
                    )
                }
            }
            .refreshable { await store.cargarDatos() }
        }
        .sheet(isPresented: $mostrarNuevoPlan) {
            PlanFormView()
        }
        .sheet(isPresented: $mostrarCompartir) {
            if let url = urlPDF {
                ShareSheet(items: [url])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitShareAccepted)) { notification in
            guard let metadata = notification.object as? CKShare.Metadata else { return }
            Task {
                do {
                    try await store.aceptarShare(metadata: metadata)
                } catch {
                    errorImport = error.localizedDescription
                }
            }
        }
        .task {
            // Handle share metadata that arrived before the view was ready
            // (e.g. app was cold-launched via a share link).
            if let delegate = UIApplication.shared.delegate as? AppDelegate,
               let metadata = delegate.pendingShareMetadata {
                delegate.pendingShareMetadata = nil
                do {
                    try await store.aceptarShare(metadata: metadata)
                } catch {
                    errorImport = error.localizedDescription
                }
            }
        }
        .alert("Error accepting invitation", isPresented: .init(
            get: { errorImport != nil },
            set: { if !$0 { errorImport = nil } }
        )) {
            Button("Accept", role: .cancel) {}
        } message: {
            Text(errorImport ?? "")
        }
    }
}

struct PlanRowView: View {
    let plan: Plan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(plan.titulo.isEmpty ? "No title" : plan.titulo)
                    .font(.headline)
                if plan.estaCompartido {
                    Image(systemName: plan.esPropio ? "person.2.fill" : "person.fill.checkmark")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            if let inicio = plan.fechaInicio {
                Text(fechas(inicio, plan.fechaFin))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func fechas(_ inicio: Date, _ fin: Date?) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        if let fin {
            return "\(fmt.string(from: inicio)) – \(fmt.string(from: fin))"
        }
        return fmt.string(from: inicio)
    }
}

#Preview {
    PlanesView()
        .environment(CloudKitStore())
}
