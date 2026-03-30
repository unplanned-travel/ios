import CloudKit

struct Etapa: Identifiable {
    var id: CKRecord.ID
    var planID: CKRecord.ID
    var tipoRaw: String
    var fechaInicio: Date
    var fechaFin: Date?
    var nombre: String?
    var notas: String?
    var coste: Coste?
    var origen: Direccion?
    var destino: Direccion?
    var direccion: Direccion?
    var reserva: Reserva?
    var rutaCircular: Bool?
    var orden: Int

    // MARK: - Computed

    var tipo: TipoEtapa {
        get { TipoEtapa(rawValue: tipoRaw) ?? .actividad }
        set { tipoRaw = newValue.rawValue }
    }

    var tieneUbicacion: Bool {
        if tipo.esTransporte {
            return origen?.tieneCoordenadas == true || destino?.tieneCoordenadas == true
        }
        return direccion?.tieneCoordenadas == true
    }

    var etiqueta: String {
        switch tipo {
        case .vuelo, .coche, .taxi, .bus, .tren, .metro, .barco:
            let o = origen.flatMap { $0.estaVacia ? nil : ($0.descripcion.isEmpty ? $0.ciudad : $0.descripcion) }
            let d = destino.flatMap { $0.estaVacia ? nil : ($0.descripcion.isEmpty ? $0.ciudad : $0.descripcion) }
            if let o, let d { return "\(o) → \(d)" }
            if let o { return "\(o) →" }
            return nombre ?? tipo.nombre
        default:
            return nombre.flatMap { $0.isEmpty ? nil : $0 } ?? tipo.nombre
        }
    }

    // MARK: - Init for new etapas (draft, not yet saved)

    init(tipo: TipoEtapa, fechaInicio: Date, planID: CKRecord.ID, orden: Int = 0) {
        let zone = CKRecordZone(zoneName: CloudKitStore.zoneName)
        self.id = CKRecord.ID(recordName: UUID().uuidString, zoneID: zone.zoneID)
        self.planID = planID
        self.tipoRaw = tipo.rawValue
        self.fechaInicio = fechaInicio
        self.orden = orden
    }

    // MARK: - Init from CloudKit record

    init(from record: CKRecord) {
        self.id = record.recordID
        self.planID = (record["planRef"] as? CKRecord.Reference)?.recordID ?? record.recordID
        self.tipoRaw = record["tipoRaw"] as? String ?? TipoEtapa.actividad.rawValue
        self.fechaInicio = record["fechaInicio"] as? Date ?? Date()
        self.fechaFin = record["fechaFin"] as? Date
        self.nombre = record["nombre"] as? String
        self.notas = record["notas"] as? String
        self.orden = record["orden"] as? Int ?? 0
        self.rutaCircular = (record["rutaCircular"] as? Int).map { $0 == 1 }
        self.coste = Self.decodificar(record["costeJSON"] as? String)
        self.origen = Self.decodificar(record["origenJSON"] as? String)
        self.destino = Self.decodificar(record["destinoJSON"] as? String)
        self.direccion = Self.decodificar(record["direccionJSON"] as? String)
        self.reserva = Self.decodificar(record["reservaJSON"] as? String)
    }

    // MARK: - JSON helpers

    private static func decodificar<T: Decodable>(_ json: String?) -> T? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func codificar<T: Encodable>(_ value: T?) -> String? {
        guard let value else { return nil }
        return try? String(data: JSONEncoder().encode(value), encoding: .utf8)
    }
}
