import SwiftUI
import SwiftData

// MARK: - Main form

struct EtapaFormView: View {
    @Bindable var etapa: Etapa
    var esNueva: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                encabezadoSection()

                switch etapa.tipo {
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
            .navigationTitle(esNueva ? "Nuevo \(etapa.tipo.nombre.lowercased())" : etapa.tipo.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if esNueva {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") {
                            modelContext.delete(etapa)
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") { dismiss() }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Hecho") { dismiss() }
                    }
                }
            }
        }
    }
}

// MARK: - Shared sections

extension EtapaFormView {

    @ViewBuilder
    func encabezadoSection() -> some View {
        Section {
            Label(etapa.tipo.nombre, systemImage: etapa.tipo.icono)
                .font(.headline)
                .foregroundStyle(.tint)
        }
    }

    @ViewBuilder
    func costesSection() -> some View {
        Section("Coste") {
            CurrencyField(label: "Previsto",
                          value: Binding(get: { etapa.coste?.previsto ?? 0 },
                                         set: { mutateCoste { $0.previsto = $1 }($0) }),
                          currency: Binding(get: { etapa.coste?.moneda ?? "EUR" },
                                            set: { mutateCoste { $0.moneda = $1 }($0) }))
            CurrencyField(label: "Extras",
                          value: Binding(get: { etapa.coste?.extras ?? 0 },
                                         set: { mutateCoste { $0.extras = $1 }($0) }),
                          currency: .constant(etapa.coste?.moneda ?? "EUR"))
            if let coste = etapa.coste, coste.total > 0 {
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
                get: { etapa.notas ?? "" },
                set: { etapa.notas = $0.isEmpty ? nil : $0 }
            ))
            .frame(minHeight: 80)
        }
    }

    // Helper: mutate optional Coste struct.
    private func mutateCoste<T>(_ fn: @escaping (inout Coste, T) -> Void) -> (T) -> Void {
        { value in
            var c = etapa.coste ?? Coste()
            fn(&c, value)
            etapa.coste = c
        }
    }
}

// MARK: - Type-specific sections

extension EtapaFormView {

    @ViewBuilder
    func vueloSections() -> some View {
        DireccionSection(titulo: "Origen", direccion: origenBinding)
        Section {
            DatePicker("Salida", selection: $etapa.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
        }
        DireccionSection(titulo: "Destino", direccion: destinoBinding)
        Section {
            DatePicker("Llegada", selection: fechaFinBinding(default: Calendar.current.date(
                byAdding: .hour, value: 2, to: etapa.fechaInicio) ?? etapa.fechaInicio),
                       displayedComponents: [.date, .hourAndMinute])
        }
        if etapa.tipo.tieneReserva {
            ReservaSection(reserva: reservaBinding)
        }
    }

    @ViewBuilder
    func hotelSections() -> some View {
        Section("Hotel") {
            TextField("Nombre del hotel", text: nombreBinding)
        }
        Section("Fechas") {
            DatePicker("Entrada", selection: $etapa.fechaInicio, displayedComponents: .date)
            DatePicker("Salida", selection: fechaFinBinding(default: Calendar.current.date(
                byAdding: .day, value: 1, to: etapa.fechaInicio) ?? etapa.fechaInicio),
                       displayedComponents: .date)
            if let fin = etapa.fechaFin {
                let noches = Calendar.current.dateComponents([.day], from: etapa.fechaInicio, to: fin).day ?? 0
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
            DatePicker("Salida", selection: $etapa.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
        }
        DireccionSection(titulo: "Destino", direccion: destinoBinding)
        Section {
            fechaFinToggle(label: "Llegada")
        }
        if etapa.tipo == .coche || etapa.tipo == .barco {
            Section("Opciones") {
                Toggle("Ruta circular", isOn: Binding(
                    get: { etapa.rutaCircular ?? false },
                    set: { etapa.rutaCircular = $0 }
                ))
            }
        }
        if etapa.tipo.tieneReserva {
            ReservaSection(reserva: reservaBinding)
        }
    }

    @ViewBuilder
    func foodDrinkSections() -> some View {
        Section {
            TextField(etapa.tipo.etiquetaNombre, text: nombreBinding)
        }
        Section("Fecha") {
            DatePicker("Hora", selection: $etapa.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
        }
        DireccionSection(titulo: "Dirección", direccion: direccionBinding)
    }

    @ViewBuilder
    func ocioSections() -> some View {
        Section {
            TextField(etapa.tipo.etiquetaNombre, text: nombreBinding)
        }
        Section("Fecha") {
            DatePicker("Inicio", selection: $etapa.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
            fechaFinToggle(label: "Fin")
        }
        DireccionSection(titulo: "Dirección", direccion: direccionBinding)
    }

    @ViewBuilder
    func actividadSections() -> some View {
        Section {
            TextField(etapa.tipo.etiquetaNombre, text: nombreBinding)
        }
        Section("Fecha") {
            DatePicker("Inicio", selection: $etapa.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
            fechaFinToggle(label: "Fin")
        }
        DireccionSection(titulo: "Dirección", direccion: direccionBinding)
    }
}

// MARK: - Binding helpers

extension EtapaFormView {

    var nombreBinding: Binding<String> {
        Binding(get: { etapa.nombre ?? "" },
                set: { etapa.nombre = $0.isEmpty ? nil : $0 })
    }

    var origenBinding: Binding<Direccion> {
        Binding(get: { etapa.origen ?? Direccion() },
                set: { etapa.origen = $0 })
    }

    var destinoBinding: Binding<Direccion> {
        Binding(get: { etapa.destino ?? Direccion() },
                set: { etapa.destino = $0 })
    }

    var direccionBinding: Binding<Direccion> {
        Binding(get: { etapa.direccion ?? Direccion() },
                set: { etapa.direccion = $0 })
    }

    var reservaBinding: Binding<Reserva> {
        Binding(get: { etapa.reserva ?? Reserva() },
                set: { etapa.reserva = $0 })
    }

    func fechaFinBinding(default defaultDate: Date) -> Binding<Date> {
        Binding(get: { etapa.fechaFin ?? defaultDate },
                set: { etapa.fechaFin = $0 })
    }

    @ViewBuilder
    func fechaFinToggle(label: String) -> some View {
        Toggle(label, isOn: Binding(
            get: { etapa.fechaFin != nil },
            set: { etapa.fechaFin = $0 ? (etapa.fechaFin ?? etapa.fechaInicio) : nil }
        ).animation())
        if etapa.fechaFin != nil {
            DatePicker(label, selection: fechaFinBinding(default: etapa.fechaInicio),
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

            // Manual entry as fallback.
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
