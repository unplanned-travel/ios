import SwiftUI
import SwiftData

struct PlanFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var plan: Plan?

    @State private var titulo = ""
    @State private var conFechas = false
    @State private var fechaInicio = Date()
    @State private var fechaFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var notas = ""

    init(plan: Plan? = nil) {
        self.plan = plan
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    TextField("Título", text: $titulo)
                }
                Section {
                    Toggle("Con fechas", isOn: $conFechas.animation())
                    if conFechas {
                        DatePicker("Comienzo", selection: $fechaInicio, displayedComponents: .date)
                        DatePicker("Fin", selection: $fechaFin,
                                   in: fechaInicio..., displayedComponents: .date)
                    }
                }
                Section("Notas") {
                    TextEditor(text: $notas)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(plan == nil ? "Nuevo plan" : "Editar plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .disabled(titulo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { cargarSiEdita() }
        }
    }

    private func cargarSiEdita() {
        guard let plan else { return }
        titulo = plan.titulo
        notas = plan.notas ?? ""
        if let fi = plan.fechaInicio {
            conFechas = true
            fechaInicio = fi
        }
        if let ff = plan.fechaFin { fechaFin = ff }
    }

    private func guardar() {
        let p = plan ?? Plan()
        p.titulo = titulo.trimmingCharacters(in: .whitespaces)
        p.fechaInicio = conFechas ? fechaInicio : nil
        p.fechaFin = conFechas ? fechaFin : nil
        p.notas = notas.isEmpty ? nil : notas
        if plan == nil { modelContext.insert(p) }
        dismiss()
    }
}
