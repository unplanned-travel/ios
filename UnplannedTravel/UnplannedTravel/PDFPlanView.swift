import SwiftUI

/// Full-plan layout rendered to PDF via ImageRenderer.
/// Fixed width of 595 pt (DIN A4 at 72 ppp) so the output is always the same regardless of device screen.
struct PDFPlanView: View {
    let plan: Plan
    let etapas: [Etapa]

    static let anchoPagina: CGFloat = 595  // A4: 210 mm a 72 ppp
    static let margen: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cabecera
                .padding(.bottom, 28)

            if etapas.isEmpty {
                Text("Sin etapas registradas.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.5))
            } else {
                ForEach(etapas) { etapa in
                    Divider()
                    EtapaPDFFila(etapa: etapa)
                }
                Divider()
            }

            pie.padding(.top, 36)
        }
        .frame(width: Self.anchoPagina)
        .padding(Self.margen)
        .background(Color.white)
    }

    // MARK: Cabecera

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("UNPLANNED")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.blue)
                .kerning(2.5)

            Text(plan.titulo.isEmpty ? "Sin título" : plan.titulo)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.black)

            if let inicio = plan.fechaInicio {
                let texto: String = {
                    let fmt = DateFormatter()
                    fmt.dateStyle = .long
                    fmt.timeStyle = .none
                    if let fin = plan.fechaFin {
                        let dias = Calendar.current.dateComponents([.day], from: inicio, to: fin).day ?? 0
                        return "\(fmt.string(from: inicio)) – \(fmt.string(from: fin))  ·  \(dias) días"
                    }
                    return fmt.string(from: inicio)
                }()
                Text(texto)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.45))
            }

            if let notas = plan.notas, !notas.isEmpty {
                Text(notas)
                    .font(.system(size: 11))
                    .italic()
                    .foregroundStyle(Color(white: 0.5))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: Pie

    private var pie: some View {
        HStack {
            Text("Generado con Unplanned")
            Spacer()
            let fmt = DateFormatter()
            let _ = { fmt.dateStyle = .medium; fmt.timeStyle = .none }()
            Text(fmt.string(from: Date()))
        }
        .font(.system(size: 9))
        .foregroundStyle(Color(white: 0.65))
    }
}

// MARK: - Fila de etapa

private struct EtapaPDFFila: View {
    let etapa: Etapa

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icono
            Image(systemName: etapa.tipo.icono)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                // Tipo
                Text(etapa.tipo.nombre.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.blue)
                    .kerning(1.2)

                // Etiqueta principal
                Text(etapa.etiqueta)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black)

                // Fechas
                filaDatos(icono: "calendar", texto: textoFechas(etapa))

                // Ubicación
                if etapa.tipo.esTransporte {
                    let partes = [etapa.origen?.resumen, etapa.destino?.resumen]
                        .compactMap { $0.flatMap { $0.isEmpty ? nil : $0 } }
                    if !partes.isEmpty {
                        filaDatos(icono: "arrow.right", texto: partes.joined(separator: " → "))
                    }
                } else if let dir = etapa.direccion, !dir.estaVacia {
                    filaDatos(icono: "mappin", texto: dir.resumen)
                }

                // Reserva
                if let r = etapa.reserva, !r.estaVacia {
                    if !r.referencia.isEmpty { filaDatos(icono: "ticket", texto: "Ref. \(r.referencia)") }
                    if !r.proveedor.isEmpty  { filaDatos(icono: "building.2", texto: r.proveedor) }
                    if !r.telefono.isEmpty   { filaDatos(icono: "phone", texto: r.telefono) }
                    if !r.web.isEmpty        { filaDatos(icono: "globe", texto: r.web) }
                }

                // Coste
                if let c = etapa.coste, c.total > 0 {
                    let totalStr = String(format: c.total.truncatingRemainder(dividingBy: 1) == 0
                                         ? "%.0f %@" : "%.2f %@", c.total, c.moneda)
                    filaDatos(icono: "eurosign.circle", texto: totalStr)
                }

                // Notas
                if let notas = etapa.notas, !notas.isEmpty {
                    Text(notas)
                        .font(.system(size: 10))
                        .italic()
                        .foregroundStyle(Color(white: 0.5))
                        .padding(.top, 1)
                }
            }
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func filaDatos(icono: String, texto: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icono)
                .font(.system(size: 9))
                .foregroundStyle(Color(white: 0.55))
                .frame(width: 12)
            Text(texto)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.4))
        }
    }

    private func textoFechas(_ etapa: Etapa) -> String {
        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .medium
        dateFmt.timeStyle = .none
        let timeFmt = DateFormatter()
        timeFmt.dateStyle = .none
        timeFmt.timeStyle = .short

        switch etapa.tipo {
        case .hotel:
            if let fin = etapa.fechaFin {
                let noches = Calendar.current.dateComponents([.day], from: etapa.fechaInicio, to: fin).day ?? 0
                return "Entrada \(dateFmt.string(from: etapa.fechaInicio))  ·  Salida \(dateFmt.string(from: fin))  ·  \(noches) noches"
            }
            return "Entrada \(dateFmt.string(from: etapa.fechaInicio))"
        default:
            var s = "\(dateFmt.string(from: etapa.fechaInicio))  \(timeFmt.string(from: etapa.fechaInicio))"
            if let fin = etapa.fechaFin {
                s += " → \(timeFmt.string(from: fin))"
            }
            return s
        }
    }
}
