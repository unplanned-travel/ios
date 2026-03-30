import SwiftUI

struct EtapaRowView: View {
    let etapa: Etapa

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: etapa.tipo.icono)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(etapa.etiqueta)
                    .font(.headline)
                HStack {
                    Text(formatFecha(etapa.fechaInicio))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let coste = etapa.coste, coste.total > 0 {
                        Text(formatCoste(coste))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatFecha(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func formatCoste(_ coste: Coste) -> String {
        let total = coste.total
        if total.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(total)) \(coste.moneda)"
        }
        return String(format: "%.2f %@", total, coste.moneda)
    }
}
