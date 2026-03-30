import SwiftUI
import MapKit

struct MapPickerView: View {
    @Binding var direccion: Direccion
    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition = .automatic
    @State private var searchText = ""
    @State private var suggestions: [MKMapItem] = []
    @State private var selectedItem: MKMapItem?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                if let item = selectedItem {
                    Marker(item: item)
                        .tint(.red)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .all))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Buscar lugar, ciudad o dirección"
            )
            .searchSuggestions {
                ForEach(suggestions, id: \.self) { item in
                    Button { seleccionar(item) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: icono(para: item))
                                .foregroundStyle(.red)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "")
                                    .foregroundStyle(.primary)
                                if let subtitulo = item.placemark.title, subtitulo != item.name {
                                    Text(subtitulo)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .onSubmit(of: .search) { buscar(searchText) }
            .onChange(of: searchText) { _, nuevo in
                searchTask?.cancel()
                if nuevo.count >= 2 {
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        buscar(nuevo)
                    }
                } else if nuevo.isEmpty {
                    suggestions = []
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let item = selectedItem {
                    tarjetaItem(item)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: selectedItem != nil)
            .navigationTitle("Seleccionar ubicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Seleccionar") { aplicar() }
                        .disabled(selectedItem == nil)
                        .bold()
                }
            }
        }
    }

    // MARK: - Search

    private func buscar(_ texto: String) {
        guard !texto.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = texto
        request.resultTypes = [.pointOfInterest, .address]
        MKLocalSearch(request: request).start { response, _ in
            guard let response else { return }
            suggestions = Array(response.mapItems.prefix(8))
            // If only one result, select it automatically.
            if response.mapItems.count == 1, let first = response.mapItems.first {
                seleccionar(first)
            } else {
                position = .region(response.boundingRegion)
            }
        }
    }

    // MARK: - Selection

    private func seleccionar(_ item: MKMapItem) {
        selectedItem = item
        searchText = item.name ?? ""
        suggestions = []
        if let coord = item.placemark.location?.coordinate {
            position = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 600,
                longitudinalMeters: 600
            ))
        }
    }

    private func aplicar() {
        guard let item = selectedItem else { return }
        let p = item.placemark
        direccion.descripcion = item.name ?? p.name ?? ""
        direccion.ciudad = p.locality ?? p.administrativeArea ?? ""
        direccion.pais = p.country ?? ""
        direccion.latitud = p.coordinate.latitude
        direccion.longitud = p.coordinate.longitude
        dismiss()
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func tarjetaItem(_ item: MKMapItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name ?? "Ubicación seleccionada")
                    .font(.headline)
                let partes = [
                    item.placemark.thoroughfare,
                    item.placemark.locality,
                    item.placemark.country
                ].compactMap { $0 }.joined(separator: ", ")
                if !partes.isEmpty {
                    Text(partes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func icono(para item: MKMapItem) -> String {
        switch item.pointOfInterestCategory {
        case .restaurant, .bakery, .foodMarket:     return "fork.knife"
        case .cafe:                                  return "cup.and.saucer"
        case .nightlife, .brewery, .winery:          return "wineglass"
        case .hotel:                                 return "bed.double"
        case .theater:                               return "theatermasks"
        case .museum:                                return "building.columns"
        case .airport:                               return "airplane"
        case .publicTransport:                       return "tram"
        case .beach:                                 return "beach.umbrella"
        case .park:                                  return "leaf"
        case .store:                                 return "bag"
        case .hospital:                              return "cross.case"
        default:                                     return "mappin"
        }
    }
}
