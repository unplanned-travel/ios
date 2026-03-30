import SwiftUI
import CloudKit

// MARK: - Main form

struct EtapaFormView: View {
    @Environment(CloudKitStore.self) var store
    @Environment(\.dismiss) private var dismiss

    let planID: CKRecord.ID
    var etapaExistente: Etapa?

    @State private var borrador: Etapa
    @State private var guardando = false
    @State private var errorGuardado: String?

    init(planID: CKRecord.ID, tipo: TipoEtapa, fechaInicio: Date, etapaExistente: Etapa? = nil) {
        self.planID = planID
        self.etapaExistente = etapaExistente
        _borrador = State(initialValue: etapaExistente ?? Etapa(tipo: tipo, fechaInicio: fechaInicio, planID: planID))
    }

    var body: some View {
        NavigationStack {
            Form {
                encabezadoSection()

                switch borrador.tipo {
                case .vuelo:
                    vueloSections()
                case .hotel:
                    hotelSections()
                case .coche, .taxi, .bus, .tren, .metro, .barco:
                    transporteSections()
                case .restaurante, .bar, .cafe:
                    foodDrinkSections()
                case .cine, .teatro, .concierto, .vidaNocturna:
                    ocioSections()
                case .visitaGuiada, .museo, .compras, .reunion, .deporte, .actividad:
                    actividadSections()
                }

                costesSection()
                notasSection()
            }
            .navigationTitle(etapaExistente == nil
                ? "Nuevo \(borrador.tipo.nombre.lowercased())"
                : borrador.tipo.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if etapaExistente == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") { guardar() }
                            .disabled(guardando)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Hecho") { guardar() }
                            .disabled(guardando)
                    }
                }
            }
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

    private func guardar() {
        guardando = true
        Task {
            do {
                if etapaExistente != nil {
                    try await store.actualizarEtapa(borrador)
                } else {
                    _ = try await store.crearEtapa(borrador)
                }
                dismiss()
            } catch {
                errorGuardado = error.localizedDescription
                guardando = false
            }
        }
    }
}

// MARK: - Shared sections

extension EtapaFormView {

    @ViewBuilder
    func encabezadoSection() -> some View {
        Section {
            Label(borrador.tipo.nombre, systemImage: borrador.tipo.icono)
                .font(.headline)
                .foregroundStyle(.tint)
        }
    }

    @ViewBuilder
    func costesSection() -> some View {
        Section("Coste") {
            CurrencyField(label: "Previsto",
                          value: Binding(get: { borrador.coste?.previsto ?? 0 },
                                         set: { mutateCoste { $0.previsto = $1 }($0) }),
                          currency: Binding(get: { borrador.coste?.moneda ?? "EUR" },
                                            set: { mutateCoste { $0.moneda = $1 }($0) }))
            CurrencyField(label: "Extras",
                          value: Binding(get: { borrador.coste?.extras ?? 0 },
                                         set: { mutateCoste { $0.extras = $1 }($0) }),
                          currency: .constant(borrador.coste?.moneda ?? "EUR"))
            if let coste = borrador.coste, coste.total > 0 {
                HStack {
                    Text("Total")
                    Spacer()
                    Text("\(coste.total, format: .number.precision(.fractionLength(2))) \(coste.moneda)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    func notasSection() -> some View {
        Section("Notas") {
            TextEditor(text: Binding(
                get: { borrador.notas ?? "" },
                set: { borrador.notas = $0.isEmpty ? nil : $0 }
            ))
            .frame(minHeight: 80)
        }
    }

    private func mutateCoste<T>(_ fn: @escaping (inout Coste, T) -> Void) -> (T) -> Void {
        { value in
            var c = borrador.coste ?? Coste()
            fn(&c, value)
            borrador.coste = c
        }
    }
}

// MARK: - Type-specific sections

extension EtapaFormView {

    @ViewBuilder
    func vueloSections() -> some View {
        DireccionSection(titulo: "Origen", direccion: origenBinding)
        Section {
            DatePicker("Salida", selection: $borrador.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
        }
        DireccionSection(titulo: "Destino", direccion: destinoBinding)
        Section {
            DatePicker("Llegada", selection: fechaFinBinding(default: Calendar.current.date(
                byAdding: .hour, value: 2, to: borrador.fechaInicio) ?? borrador.fechaInicio),
                       displayedComponents: [.date, .hourAndMinute])
        }
        if borrador.tipo.tieneReserva {
            ReservaSection(reserva: reservaBinding)
        }
    }

    @ViewBuilder
    func hotelSections() -> some View {
        Section("Hotel") {
            TextField("Nombre del hotel", text: nombreBinding)
        }
        Section("Fechas") {
            DatePicker("Entrada", selection: $borrador.fechaInicio, displayedComponents: .date)
            DatePicker("Salida", selection: fechaFinBinding(default: Calendar.current.date(
                byAdding: .day, value: 1, to: borrador.fechaInicio) ?? borrador.fechaInicio),
                       displayedComponents: .date)
            if let fin = borrador.fechaFin {
                let noches = Calendar.current.dateComponents([.day], from: borrador.fechaInicio, to: fin).day ?? 0
                HStack {
                    Text("Noches")
                    Spacer()
                    Text("\(noches)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        DireccionSection(titulo: "Dirección", direccion: direccionBinding)
        ReservaSection(reserva: reservaBinding)
    }

    @ViewBuilder
    func transporteSections() -> some View {
        DireccionSection(titulo: "Origen", direccion: origenBinding)
        Section {
            DatePicker("Salida", selection: $borrador.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
        }
        DireccionSection(titulo: "Destino", direccion: destinoBinding)
        Section {
            fechaFinToggle(label: "Llegada")
        }
        if borrador.tipo == .coche || borrador.tipo == .barco {
            Section("Opciones") {
                Toggle("Ruta circular", isOn: Binding(
                    get: { borrador.rutaCircular ?? false },
                    set: { borrador.rutaCircular = $0 }
                ))
            }
        }
        if borrador.tipo.tieneReserva {
            ReservaSection(reserva: reservaBinding)
        }
    }

    @ViewBuilder
    func foodDrinkSections() -> some View {
        Section {
            TextField(borrador.tipo.etiquetaNombre, text: nombreBinding)
        }
        Section("Fecha") {
            DatePicker("Hora", selection: $borrador.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
        }
        DireccionSection(titulo: "Dirección", direccion: direccionBinding)
    }

    @ViewBuilder
    func ocioSections() -> some View {
        Section {
            TextField(borrador.tipo.etiquetaNombre, text: nombreBinding)
        }
        Section("Fecha") {
            DatePicker("Inicio", selection: $borrador.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
            fechaFinToggle(label: "Fin")
        }
        DireccionSection(titulo: "Dirección", direccion: direccionBinding)
    }

    @ViewBuilder
    func actividadSections() -> some View {
        Section {
            TextField(borrador.tipo.etiquetaNombre, text: nombreBinding)
        }
        Section("Fecha") {
            DatePicker("Inicio", selection: $borrador.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
            fechaFinToggle(label: "Fin")
        }
        DireccionSection(titulo: "Dirección", direccion: direccionBinding)
    }
}

// MARK: - Binding helpers

extension EtapaFormView {

    var nombreBinding: Binding<String> {
        Binding(get: { borrador.nombre ?? "" },
                set: { borrador.nombre = $0.isEmpty ? nil : $0 })
    }

    var origenBinding: Binding<Direccion> {
        Binding(get: { borrador.origen ?? Direccion() },
                set: { borrador.origen = $0 })
    }

    var destinoBinding: Binding<Direccion> {
        Binding(get: { borrador.destino ?? Direccion() },
                set: { borrador.destino = $0 })
    }

    var direccionBinding: Binding<Direccion> {
        Binding(get: { borrador.direccion ?? Direccion() },
                set: { borrador.direccion = $0 })
    }

    var reservaBinding: Binding<Reserva> {
        Binding(get: { borrador.reserva ?? Reserva() },
                set: { borrador.reserva = $0 })
    }

    func fechaFinBinding(default defaultDate: Date) -> Binding<Date> {
        Binding(get: { borrador.fechaFin ?? defaultDate },
                set: { borrador.fechaFin = $0 })
    }

    @ViewBuilder
    func fechaFinToggle(label: String) -> some View {
        Toggle(label, isOn: Binding(
            get: { borrador.fechaFin != nil },
            set: { borrador.fechaFin = $0 ? (borrador.fechaFin ?? borrador.fechaInicio) : nil }
        ).animation())
        if borrador.fechaFin != nil {
            DatePicker(label, selection: fechaFinBinding(default: borrador.fechaInicio),
                       displayedComponents: [.date, .hourAndMinute])
        }
    }
}

// MARK: - Sub-views

struct DireccionSection: View {
    let titulo: String
    @Binding var direccion: Direccion
    @State private var mostrarMapa = false

    var body: some View {
        Section(titulo) {
            Button {
                mostrarMapa = true
            } label: {
                Label("Buscar en el mapa", systemImage: "map")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !direccion.estaVacia {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if !direccion.descripcion.isEmpty {
                            Text(direccion.descripcion)
                                .font(.subheadline)
                        }
                        let lugar = [direccion.ciudad, direccion.pais]
                            .filter { !$0.isEmpty }.joined(separator: ", ")
                        if !lugar.isEmpty {
                            Text(lugar)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        direccion = Direccion()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Nombre del lugar", text: $direccion.descripcion)
                .font(.caption)
            TextField("Ciudad", text: $direccion.ciudad)
                .font(.caption)
            TextField("País", text: $direccion.pais)
                .font(.caption)
        }
        .sheet(isPresented: $mostrarMapa) {
            MapPickerView(direccion: $direccion)
        }
    }
}

struct ReservaSection: View {
    @Binding var reserva: Reserva

    var body: some View {
        Section("Reserva") {
            TextField("Referencia", text: $reserva.referencia)
            TextField("Proveedor", text: $reserva.proveedor)
            TextField("Teléfono", text: $reserva.telefono)
                .keyboardType(.phonePad)
            TextField("Email", text: $reserva.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            TextField("Web", text: $reserva.web)
                .keyboardType(.URL)
                .autocapitalization(.none)
            TextField("Notas de reserva", text: $reserva.notas)
        }
    }
}

struct CurrencyField: View {
    let label: String
    @Binding var value: Double
    @Binding var currency: String

    private let currencies = ["EUR", "USD", "GBP", "JPY", "CHF", "MXN", "ARS", "BRL"]

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: $value, format: .number.precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
            Picker("Moneda", selection: $currency) {
                ForEach(currencies, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}
