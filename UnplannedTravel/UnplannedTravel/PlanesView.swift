import SwiftUI
import SwiftData

struct PlanesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Plan.fechaInicio) private var planes: [Plan]

    @State private var mostrarNuevoPlan = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(planes) { plan in
                    NavigationLink(destination: PlanDetailView(plan: plan)) {
                        PlanRowView(plan: plan)
                    }
                }
                .onDelete(perform: eliminarPlanes)
            }
            .navigationTitle("Unplanned")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { mostrarNuevoPlan = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if planes.isEmpty {
                    ContentUnavailableView(
                        "Sin planes",
                        systemImage: "map",
                        description: Text("Añade tu primer viaje con el botón +")
                    )
                }
            }
        }
        .sheet(isPresented: $mostrarNuevoPlan) {
            PlanFormView()
        }
    }

    private func eliminarPlanes(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(planes[index]) }
    }
}

struct PlanRowView: View {
    let plan: Plan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.titulo.isEmpty ? "Sin título" : plan.titulo)
                .font(.headline)
            HStack(spacing: 8) {
                if let inicio = plan.fechaInicio {
                    Text(fechas(inicio, plan.fechaFin))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !plan.etapas.isEmpty {
                    Text("\(plan.etapas.count) etapas")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
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
        .modelContainer(for: [Plan.self, Etapa.self], inMemory: true)
}
