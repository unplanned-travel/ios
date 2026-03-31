import SwiftUI
import MapKit
import CoreLocation

// Wrapper to make selected MKMapItem usable as an annotation item.
private struct SelectedMapItem: Identifiable {
    let id = UUID()
    let item: MKMapItem
    var coordinate: CLLocationCoordinate2D { item.placemark.coordinate }
}

struct MapPickerView: View {
    @Binding var direccion: Direccion
    @Environment(\.dismiss) private var dismiss

    @State private var region: MKCoordinateRegion
    @State private var searchText = ""
    @State private var suggestions: [MKMapItem] = []
    @State private var selectedItem: MKMapItem?
    @State private var searchTask: Task<Void, Never>?
    @State private var buscandoPOI = false
    @State private var radioActual: Double = 400
    @StateObject private var locationManager = LocationManager()

    private static let radioDefecto: Double = 400

    init(direccion: Binding<Direccion>) {
        _direccion = direccion
        let d = direccion.wrappedValue
        if let lat = d.latitud, let lon = d.longitud {
            let radio = d.radioMetros ?? MapPickerView.radioDefecto
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                latitudinalMeters: radio,
                longitudinalMeters: radio
            ))
            _radioActual = State(initialValue: radio)
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                latitudinalMeters: 400,
                longitudinalMeters: 400
            ))
        }
    }

    private var annotationItems: [SelectedMapItem] {
        guard let item = selectedItem else { return [] }
        return [SelectedMapItem(item: item)]
    }

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: annotationItems) { wrapper in
                MapMarker(coordinate: wrapper.coordinate, tint: .red)
            }
            .onChange(of: region) { newRegion in
                radioActual = newRegion.span.latitudeDelta * 111_000
            }
            .task {
                if let lat = direccion.latitud, let lon = direccion.longitud {
                    let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    let item = MKMapItem(placemark: placemark)
                    item.name = direccion.descripcion.isEmpty ? direccion.ciudad : direccion.descripcion
                    selectedItem = item
                    searchText = item.name ?? ""
                } else {
                    locationManager.requestLocation { coordinate in
                        region = MKCoordinateRegion(
                            center: coordinate,
                            latitudinalMeters: 400,
                            longitudinalMeters: 400
                        )
                    }
                }
            }
            .onChange(of: searchText) { nuevo in
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
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search for a place, city or address"
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
                                let subtitulo = shortAddress(for: item.placemark)
                                if !subtitulo.isEmpty && subtitulo != item.name {
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
            .safeAreaInset(edge: .bottom) {
                if buscandoPOI {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.bottom, 8)
                        .transition(.opacity)
                } else if let item = selectedItem {
                    tarjetaItem(item)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedItem?.name)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: buscandoPOI)
            .navigationTitle("Select location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
            if response.mapItems.count == 1, let first = response.mapItems.first {
                seleccionar(first)
            }
        }
    }

    // MARK: - Selection

    private func seleccionar(_ item: MKMapItem) {
        selectedItem = item
        searchText = item.name ?? ""
        suggestions = []
        let coord = item.placemark.coordinate
        region = MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
    }

    private func aplicar() {
        guard let item = selectedItem else { return }
        let placemark = item.placemark
        direccion.descripcion = item.name ?? ""
        let parts = [placemark.thoroughfare, placemark.locality,
                     placemark.administrativeArea, placemark.country]
            .compactMap { $0 }.filter { !$0.isEmpty }
        direccion.direccionCompleta = parts.joined(separator: ", ")
        direccion.ciudad = placemark.locality ?? placemark.administrativeArea ?? ""
        direccion.pais = placemark.country ?? ""
        let coord = placemark.coordinate
        direccion.latitud = coord.latitude
        direccion.longitud = coord.longitude
        direccion.radioMetros = radioActual
        dismiss()
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func tarjetaItem(_ item: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icono(para: item))
                    .font(.title2)
                    .foregroundStyle(.red)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name ?? "Selected location")
                        .font(.headline)

                    let subtitulo = shortAddress(for: item.placemark)
                    if !subtitulo.isEmpty {
                        Text(subtitulo)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    selectedItem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            if let phone = item.phoneNumber, !phone.isEmpty {
                Label(phone, systemImage: "phone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let url = item.url {
                Label(url.host ?? url.absoluteString, systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button(action: aplicar) {
                Label("Use this location", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func shortAddress(for placemark: MKPlacemark) -> String {
        [placemark.thoroughfare, placemark.locality]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

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
