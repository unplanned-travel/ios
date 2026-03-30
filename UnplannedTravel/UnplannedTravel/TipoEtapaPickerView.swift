import SwiftUI

struct TipoEtapaPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSeleccion: (TipoEtapa) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(TipoEtapa.Categoria.allCases) { categoria in
                    Section(categoria.titulo) {
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
            .navigationTitle("New stage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
