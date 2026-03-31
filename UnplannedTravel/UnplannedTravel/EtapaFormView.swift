import SwiftUI
import CloudKit

// MARK: - Main form

struct EtapaFormView: View {
    @EnvironmentObject var store: CloudKitStore
    @Environment(\.dismiss) private var dismiss

    let planID: CKRecord.ID
    var etapaExistente: Etapa?

    @State private var borrador: Etapa
    @State private var guardando = false
    @State private var errorGuardado: String?

    // Single map sheet for the whole form — avoids "already presenting" conflicts
    // when multiple DireccionSection sub-views exist simultaneously.
    private enum SlotMapa: Int, Identifiable {
        case origen, destino, principal
        var id: Int { rawValue }
    }
    @State private var slotMapa: SlotMapa? = nil

    private var bindingParaSlotMapa: Binding<Direccion> {
        switch slotMapa {
        case .origen:    return origenBinding
        case .destino:   return destinoBinding
        case .principal, nil: return direccionBinding
        }
    }

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
                ? String(format: NSLocalizedString("New %@", comment: "New stage form title"), borrador.tipo.nombre.lowercased())
                : borrador.tipo.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if etapaExistente == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { guardar() }
                            .disabled(guardando)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { guardar() }
                            .disabled(guardando)
                    }
                }
            }
            .alert("Error saving", isPresented: .init(
                get: { errorGuardado != nil },
                set: { if !$0 { errorGuardado = nil } }
            )) {
                Button("Accept", role: .cancel) {}
            } message: {
                Text(errorGuardado ?? "")
            }
        }
        .sheet(item: $slotMapa) { _ in
            MapPickerView(direccion: bindingParaSlotMapa)
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
        Section("Cost") {
            CurrencyField(label: "Estimated",
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
        Section("Notes") {
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
        DireccionSection(titulo: "Origin", direccion: origenBinding, onBuscarEnMapa: { slotMapa = .origen })
        Section {
            DatePicker("Departure", selection: $borrador.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
        }
        DireccionSection(titulo: "Destination", direccion: destinoBinding, onBuscarEnMapa: { slotMapa = .destino })
        Section {
            DatePicker("Arrival", selection: fechaFinBinding(default: Calendar.current.date(
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
            TextField("Hotel name", text: nombreBinding)
        }
        Section("Dates") {
            DatePicker("Check-in", selection: $borrador.fechaInicio, displayedComponents: .date)
            DatePicker("Check-out", selection: fechaFinBinding(default: Calendar.current.date(
                byAdding: .day, value: 1, to: borrador.fechaInicio) ?? borrador.fechaInicio),
                       displayedComponents: .date)
            if let fin = borrador.fechaFin {
                let noches = Calendar.current.dateComponents([.day], from: borrador.fechaInicio, to: fin).day ?? 0
                HStack {
                    Text("Nights")
                    Spacer()
                    Text("\(noches)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        DireccionSection(titulo: "Address", direccion: direccionBinding, onBuscarEnMapa: { slotMapa = .principal })
        ReservaSection(reserva: reservaBinding)
    }

    @ViewBuilder
    func transporteSections() -> some View {
        DireccionSection(titulo: "Origin", direccion: origenBinding, onBuscarEnMapa: { slotMapa = .origen })
        Section {
            DatePicker("Departure", selection: $borrador.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
        }
        DireccionSection(titulo: "Destination", direccion: destinoBinding, onBuscarEnMapa: { slotMapa = .destino })
        Section {
            fechaFinToggle(label: "Arrival")
        }
        if borrador.tipo == .coche || borrador.tipo == .barco {
            Section("Options") {
                Toggle("Round trip", isOn: Binding(
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
        Section("Date") {
            DatePicker("Time", selection: $borrador.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
        }
        DireccionSection(titulo: "Address", direccion: direccionBinding, onBuscarEnMapa: { slotMapa = .principal })
    }

    @ViewBuilder
    func ocioSections() -> some View {
        Section {
            TextField(borrador.tipo.etiquetaNombre, text: nombreBinding)
        }
        Section("Date") {
            DatePicker("Start", selection: $borrador.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
            fechaFinToggle(label: "End")
        }
        DireccionSection(titulo: "Address", direccion: direccionBinding, onBuscarEnMapa: { slotMapa = .principal })
    }

    @ViewBuilder
    func actividadSections() -> some View {
        Section {
            TextField(borrador.tipo.etiquetaNombre, text: nombreBinding)
        }
        Section("Date") {
            DatePicker("Start", selection: $borrador.fechaInicio,
                       displayedComponents: [.date, .hourAndMinute])
            fechaFinToggle(label: "End")
        }
        DireccionSection(titulo: "Address", direccion: direccionBinding, onBuscarEnMapa: { slotMapa = .principal })
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
    let onBuscarEnMapa: () -> Void

    var body: some View {
        Section(titulo) {
            Button {
                onBuscarEnMapa()
            } label: {
                Label(
                    direccion.tieneCoordenadas ? "Show on map" : "Search on map",
                    systemImage: direccion.tieneCoordenadas ? "mappin.and.ellipse" : "map"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !direccion.estaVacia {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        if !direccion.descripcion.isEmpty {
                            Text(direccion.descripcion)
                                .font(.subheadline).bold()
                        }
                        if !direccion.direccionCompleta.isEmpty {
                            Text(direccion.direccionCompleta)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

            TextField("Place name", text: $direccion.descripcion)
                .font(.caption)
            TextField("Full address", text: $direccion.direccionCompleta)
                .font(.caption)
            TextField("City", text: $direccion.ciudad)
                .font(.caption)
            TextField("Country", text: $direccion.pais)
                .font(.caption)
        }
    }
}

struct ReservaSection: View {
    @Binding var reserva: Reserva

    var body: some View {
        Section("Booking") {
            TextField("Reference", text: $reserva.referencia)
            TextField("Provider", text: $reserva.proveedor)
            TextField("Phone", text: $reserva.telefono)
                .keyboardType(.phonePad)
            TextField("Email", text: $reserva.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            TextField("Web", text: $reserva.web)
                .keyboardType(.URL)
                .autocapitalization(.none)
            TextField("Booking notes", text: $reserva.notas)
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
