import SwiftUI

struct PlanFormView: View {
    @Environment(CloudKitStore.self) var store
    @Environment(\.dismiss) private var dismiss

    var plan: Plan?

    @State private var titulo = ""
    @State private var conFechas = false
    @State private var fechaInicio = Date()
    @State private var fechaFin = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var notas = ""
    @State private var guardando = false
    @State private var errorGuardado: String?

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
                        .disabled(titulo.trimmingCharacters(in: .whitespaces).isEmpty || guardando)
                }
            }
            .onAppear { cargarSiEdita() }
            .alert("Error al guardar", isPresented: .init(
                get: { errorGuardado != nil },
                set: { if !$0 { errorGuardado = nil } }
            )) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(errorGuardado ?? "")
            }
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
        guardando = true
        var borrador = plan ?? Plan()
        borrador.titulo = titulo.trimmingCharacters(in: .whitespaces)
        borrador.fechaInicio = conFechas ? fechaInicio : nil
        borrador.fechaFin = conFechas ? fechaFin : nil
        borrador.notas = notas.isEmpty ? nil : notas
        Task {
            do {
                if plan == nil {
                    _ = try await store.crearPlan(borrador)
                } else {
                    try await store.actualizarPlan(borrador)
                }
                dismiss()
            } catch {
                errorGuardado = error.localizedDescription
                guardando = false
            }
        }
    }
}
