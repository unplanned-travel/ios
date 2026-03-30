import SwiftUI
import CloudKit

struct PlanDetailView: View {
    @Environment(CloudKitStore.self) var store
    let planID: CKRecord.ID

    private var plan: Plan? { store.planes.first { $0.id == planID } }
    private var etapas: [Etapa] { store.etapasOrdenadas(para: planID) }

    @State private var mostrarPicker = false
    @State private var tipoSeleccionado: TipoEtapa?
    @State private var mostrarNuevaEtapa = false
    @State private var etapaParaEditar: Etapa?
    @State private var etapaParaMapa: Etapa?
    @State private var mostrarEditarPlan = false
    @State private var mostrarCompartirICloud = false
    @State private var mostrarCompartir = false
    @State private var generandoPDF = false
    @State private var urlPDF: URL?

    var body: some View {
        List {
            ForEach(etapas) { etapa in
                Button { etapaParaEditar = etapa } label: {
                    EtapaRowView(etapa: etapa)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if etapa.tieneUbicacion {
                        Button {
                            etapaParaMapa = etapa
                        } label: {
                            Label("Ver en el mapa", systemImage: "map")
                        }
                    }
                    Button {
                        etapaParaEditar = etapa
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    if plan?.esPropio == true {
                        Button(role: .destructive) {
                            Task { try? await store.eliminarEtapa(etapa) }
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }
            .onDelete { offsets in
                let targets = offsets.map { etapas[$0] }
                Task {
                    for e in targets { try? await store.eliminarEtapa(e) }
                }
            }
        }
        .navigationTitle(plan?.titulo ?? "Viaje")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if plan?.esPropio == true {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { mostrarEditarPlan = true } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { mostrarCompartirICloud = true } label: {
                    Image(systemName: plan?.estaCompartido == true ? "person.2.fill" : "person.badge.plus")
                }
                .disabled(etapas.isEmpty || plan?.esPropio == false)
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
                    if generandoPDF {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
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
        .overlay {
            if etapas.isEmpty {
                ContentUnavailableView(
                    "Sin etapas",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Añade la primera etapa con el botón +")
                )
            }
        }
        .sheet(isPresented: $mostrarPicker) {
            TipoEtapaPickerView { tipo in
                tipoSeleccionado = tipo
            }
        }
        .sheet(isPresented: $mostrarNuevaEtapa) {
            if let tipo = tipoSeleccionado, let plan {
                EtapaFormView(planID: plan.id, tipo: tipo, fechaInicio: ultimaFecha())
            }
        }
        .sheet(item: $etapaParaEditar) { etapa in
            EtapaFormView(planID: planID, tipo: etapa.tipo, fechaInicio: etapa.fechaInicio, etapaExistente: etapa)
        }
        .sheet(item: $etapaParaMapa) { etapa in
            EtapaMapView(etapa: etapa)
        }
        .sheet(isPresented: $mostrarCompartirICloud) {
            if let plan { CloudSharingView(plan: plan) }
        }
        .sheet(isPresented: $mostrarCompartir) {
            if let url = urlPDF { ShareSheet(items: [url]) }
        }
        .sheet(isPresented: $mostrarEditarPlan) {
            if let plan { PlanFormView(plan: plan) }
        }
        .onChange(of: mostrarPicker) { _, isPresented in
            if !isPresented && tipoSeleccionado != nil {
                mostrarNuevaEtapa = true
            }
        }
        .onChange(of: mostrarNuevaEtapa) { _, isPresented in
            if !isPresented { tipoSeleccionado = nil }
        }
    }

    private func ultimaFecha() -> Date {
        etapas.last?.fechaFin ?? etapas.last?.fechaInicio ?? plan?.fechaInicio ?? Date()
    }
}
