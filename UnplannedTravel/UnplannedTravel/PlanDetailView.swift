import SwiftUI
import CloudKit

struct PlanDetailView: View {
    @EnvironmentObject var store: CloudKitStore
    let planID: CKRecord.ID

    private var plan: Plan? { store.planes.first { $0.id == planID } }
    private var etapas: [Etapa] { store.etapasOrdenadas(para: planID) }

    @State private var mostrarPicker = false
    @State private var tipoSeleccionado: TipoEtapa?
    @State private var mostrarNuevaEtapa = false
    @State private var etapaParaEditar: Etapa?
    @State private var etapaParaMapa: Etapa?
    @State private var mostrarEditarPlan = false
    @State private var shareActivo: SharePresentation?
    @State private var preparandoShare = false
    @State private var mostrarCompartir = false
    @State private var generandoPDF = false
    @State private var urlPDF: URL?
    @State private var errorCompartir: String?

    var body: some View {
        listaView
            .sheet(isPresented: $mostrarPicker) {
                TipoEtapaPickerView { tipo in tipoSeleccionado = tipo }
            }
            .sheet(isPresented: $mostrarNuevaEtapa) {
                if let tipo = tipoSeleccionado, let plan {
                    EtapaFormView(planID: plan.id, tipo: tipo, fechaInicio: ultimaFecha())
                }
            }
            .sheet(item: $etapaParaEditar) { etapa in
                EtapaFormView(planID: planID, tipo: etapa.tipo, fechaInicio: etapa.fechaInicio, etapaExistente: etapa)
            }
            .sheet(item: $etapaParaMapa) { etapa in EtapaMapView(etapa: etapa) }
            .sheet(isPresented: $mostrarCompartir) {
                if let url = urlPDF { ShareSheet(items: [url]) }
            }
            .sheet(item: $shareActivo) { presentation in
                if let p = plan {
                    DirectSharingView(
                        plan: p,
                        share: presentation.share,
                        container: store.ckContainer,
                        onDismiss: { shareActivo = nil },
                        onStopSharing: {
                            Task { await store.actualizarTrasDetenerShare(para: p) }
                        }
                    )
                }
            }
            .sheet(isPresented: $mostrarEditarPlan) {
                if let plan { PlanFormView(plan: plan) }
            }
            .alert("Error sharing", isPresented: .init(
                get: { errorCompartir != nil },
                set: { if !$0 { errorCompartir = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorCompartir ?? "")
            }
            .onChange(of: mostrarPicker) { isPresented in
                if !isPresented && tipoSeleccionado != nil { mostrarNuevaEtapa = true }
            }
            .onChange(of: mostrarNuevaEtapa) { isPresented in
                if !isPresented { tipoSeleccionado = nil }
            }
    }

    // MARK: - Sub-views

    private var listaView: some View {
        List {
            ForEach(etapas) { etapa in
                etapaRow(etapa)
            }
            .onDelete { offsets in
                let targets = offsets.map { etapas[$0] }
                Task {
                    for e in targets { try? await store.eliminarEtapa(e) }
                }
            }
        }
        .navigationTitle(plan?.titulo ?? "Trip")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .overlay {
            if etapas.isEmpty {
                UnavailableView(title: "No stages", systemImage: "list.bullet.clipboard", description: "Add the first stage with the + button")
            }
        }
    }

    @ViewBuilder
    private func etapaRow(_ etapa: Etapa) -> some View {
        Button { etapaParaEditar = etapa } label: {
            EtapaRowView(etapa: etapa).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if etapa.tieneUbicacion {
                Button { etapaParaMapa = etapa } label: {
                    Label("View on map", systemImage: "map")
                }
            }
            Button { etapaParaEditar = etapa } label: {
                Label("Edit", systemImage: "pencil")
            }
            if plan?.esPropio == true {
                Button(role: .destructive) {
                    Task { try? await store.eliminarEtapa(etapa) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if plan?.esPropio == true {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { mostrarEditarPlan = true } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                guard let plan else { return }
                preparandoShare = true
                Task {
                    do {
                        shareActivo = SharePresentation(share: try await store.obtenerOCrearShare(para: plan))
                    } catch {
                        errorCompartir = error.localizedDescription
                    }
                    preparandoShare = false
                }
            } label: {
                if preparandoShare {
                    ProgressView()
                } else {
                    Image(systemName: plan?.estaCompartido == true ? "person.2.fill" : "person.badge.plus")
                }
            }
            .disabled(etapas.isEmpty || plan?.esPropio == false || preparandoShare)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                if let plan {
                    generandoPDF = true
                    urlPDF = plan.generarPDF(etapas: etapas)
                    mostrarCompartir = true
                    generandoPDF = false
                }
            } label: {
                if generandoPDF { ProgressView() } else { Image(systemName: "square.and.arrow.up") }
            }
            .disabled(generandoPDF || etapas.isEmpty)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            EditButton()
        }
        if plan?.esPropio == true {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { mostrarPicker = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func ultimaFecha() -> Date {
        etapas.last?.fechaFin ?? etapas.last?.fechaInicio ?? plan?.fechaInicio ?? Date()
    }
}
