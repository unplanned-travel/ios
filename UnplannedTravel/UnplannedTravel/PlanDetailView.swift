import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @Bindable var plan: Plan
    @Environment(\.modelContext) private var modelContext

    @State private var mostrarPicker = false
    @State private var mostrarEditarPlan = false
    @State private var etapaParaCrear: Etapa?
    @State private var etapaParaEditar: Etapa?
    @State private var etapaParaMapa: Etapa?
    @State private var generandoPDF = false
    @State private var urlPDF: URL?
    @State private var mostrarCompartir = false

    var body: some View {
        List {
            ForEach(plan.etapasOrdenadas) { etapa in
                Button {
                    etapaParaEditar = etapa
                } label: {
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
                }
            }
            .onDelete(perform: eliminarEtapas)
        }
        .navigationTitle(plan.titulo)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { mostrarEditarPlan = true } label: {
                    Image(systemName: "pencil")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    generandoPDF = true
                    urlPDF = plan.generarPDF()
                    mostrarCompartir = true
                    generandoPDF = false
                } label: {
                    if generandoPDF {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(generandoPDF || plan.etapas.isEmpty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { mostrarPicker = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .overlay {
            if plan.etapas.isEmpty {
                ContentUnavailableView(
                    "Sin etapas",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Añade la primera etapa con el botón +")
                )
            }
        }
        .sheet(isPresented: $mostrarPicker) {
            TipoEtapaPickerView { tipo in
                let etapa = Etapa(tipo: tipo, fechaInicio: ultimaFecha())
                modelContext.insert(etapa)
                etapa.plan = plan
                etapaParaCrear = etapa
            }
        }
        .sheet(item: $etapaParaCrear) { etapa in
            EtapaFormView(etapa: etapa, esNueva: true)
        }
        .sheet(item: $etapaParaEditar) { etapa in
            EtapaFormView(etapa: etapa, esNueva: false)
        }
        .sheet(item: $etapaParaMapa) { etapa in
            EtapaMapView(etapa: etapa)
        }
        .sheet(isPresented: $mostrarCompartir) {
            if let url = urlPDF {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $mostrarEditarPlan) {
            PlanFormView(plan: plan)
        }
    }

    private func eliminarEtapas(at offsets: IndexSet) {
        let ordenadas = plan.etapasOrdenadas
        for index in offsets { modelContext.delete(ordenadas[index]) }
    }

    private func ultimaFecha() -> Date {
        plan.etapasOrdenadas.last?.fechaFin
            ?? plan.etapasOrdenadas.last?.fechaInicio
            ?? plan.fechaInicio
            ?? Date()
    }
}
