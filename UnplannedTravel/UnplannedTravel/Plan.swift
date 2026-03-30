import CloudKit

struct Plan: Identifiable {
    var id: CKRecord.ID
    var titulo: String
    var fechaInicio: Date?
    var fechaFin: Date?
    var notas: String?
    /// True if this plan is shared with others or received from someone else.
    var estaCompartido: Bool
    /// False for plans received from another iCloud user via a share.
    var esPropio: Bool

    // MARK: - Init for new plans (before saving to CloudKit)

    init(titulo: String = "", fechaInicio: Date? = nil, fechaFin: Date? = nil, notas: String? = nil) {
        let zone = CKRecordZone(zoneName: CloudKitStore.zoneName)
        self.id = CKRecord.ID(zoneID: zone.zoneID)
        self.titulo = titulo
        self.fechaInicio = fechaInicio
        self.fechaFin = fechaFin
        self.notas = notas
        self.estaCompartido = false
        self.esPropio = true
    }

    // MARK: - Init from CloudKit record

    init(from record: CKRecord, esPropio: Bool = true) {
        self.id = record.recordID
        self.titulo = record["titulo"] as? String ?? ""
        self.fechaInicio = record["fechaInicio"] as? Date
        self.fechaFin = record["fechaFin"] as? Date
        self.notas = record["notas"] as? String
        self.estaCompartido = record.share != nil || !esPropio
        self.esPropio = esPropio
    }
}
