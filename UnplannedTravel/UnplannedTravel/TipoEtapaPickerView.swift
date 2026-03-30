import SwiftUI

struct TipoEtapaPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSeleccion: (TipoEtapa) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(TipoEtapa.Categoria.allCases) { categoria in
                    Section(categoria.rawValue) {
                        ForEach(categoria.tipos) { tipo in
                            Button {
                                onSeleccion(tipo)
                                dismiss()
                            } label: {
                                Label(tipo.nombre, systemImage: tipo.icono)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nueva etapa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
