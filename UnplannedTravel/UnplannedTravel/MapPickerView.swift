import SwiftUI
import MapKit
import CoreLocation

struct MapPickerView: View {
    @Binding var direccion: Direccion
    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition
    @State private var searchText = ""
    @State private var suggestions: [MKMapItem] = []
    @State private var selectedItem: MKMapItem?
    @State private var searchTask: Task<Void, Never>?
    @State private var featureSeleccionada: MapFeature?
    @State private var buscandoPOI = false
    @StateObject private var locationManager = LocationManager()

    init(direccion: Binding<Direccion>) {
        _direccion = direccion
        // If coordinates already exist, open centered on them; otherwise automatic.
        if let lat = direccion.wrappedValue.latitud,
           let lon = direccion.wrappedValue.longitud {
            _position = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )))
        } else {
            _position = State(initialValue: .automatic)
        }
    }

    var body: some View {
        NavigationStack {
            Map(position: $position, selection: $featureSeleccionada) {
                UserAnnotation()
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
            .task {
                // If the direccion already has a saved location, restore the marker.
                if let lat = direccion.latitud, let lon = direccion.longitud {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let placemark = MKPlacemark(coordinate: coord)
                    let item = MKMapItem(placemark: placemark)
                    item.name = direccion.descripcion.isEmpty ? direccion.ciudad : direccion.descripcion
                    selectedItem = item
                    searchText = item.name ?? ""
                } else {
                    // No saved location: center on user position.
                    locationManager.requestLocation { coordinate in
                        position = .region(MKCoordinateRegion(
                            center: coordinate,
                            latitudinalMeters: 400,
                            longitudinalMeters: 400
                        ))
                    }
                }
            }
            .onChange(of: featureSeleccionada) { _, feature in
                guard let feature else { return }
                resolverFeature(feature)
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
            .animation(.spring(duration: 0.3), value: selectedItem?.name)
            .animation(.spring(duration: 0.2), value: buscandoPOI)
            .navigationTitle("Select location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - POI tap resolution

    /// Converts a tapped MapFeature to an MKMapItem via local search.
    private func resolverFeature(_ feature: MapFeature) {
        buscandoPOI = true
        selectedItem = nil

        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = feature.title
            request.region = MKCoordinateRegion(
                center: feature.coordinate,
                latitudinalMeters: 150,
                longitudinalMeters: 150
            )
            request.resultTypes = .pointOfInterest

            if let response = try? await MKLocalSearch(request: request).start(),
               let match = response.mapItems.min(by: {
                   distancia($0.placemark.coordinate, feature.coordinate) <
                   distancia($1.placemark.coordinate, feature.coordinate)
               }) {
                seleccionar(match)
            } else {
                // Fallback: build a minimal item from the feature itself
                let placemark = MKPlacemark(coordinate: feature.coordinate)
                let item = MKMapItem(placemark: placemark)
                item.name = feature.title
                seleccionar(item)
            }
            buscandoPOI = false
        }
    }

    private func distancia(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let la = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let lb = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return la.distance(from: lb)
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
            } else {
                position = .region(response.boundingRegion)
            }
        }
    }

    // MARK: - Selection

    private func seleccionar(_ item: MKMapItem) {
        selectedItem = item
        featureSeleccionada = nil
        searchText = item.name ?? ""
        suggestions = []
        if let coord = item.placemark.location?.coordinate {
            position = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            ))
        }
    }

    private func aplicar() {
        guard let item = selectedItem else { return }
        let p = item.placemark
        direccion.descripcion = item.name ?? p.name ?? ""
        direccion.direccionCompleta = formatearDireccion(p)
        direccion.ciudad = p.locality ?? p.administrativeArea ?? ""
        direccion.pais = p.country ?? ""
        direccion.latitud = p.coordinate.latitude
        direccion.longitud = p.coordinate.longitude
        dismiss()
    }

    private func formatearDireccion(_ p: MKPlacemark) -> String {
        let numero = p.subThoroughfare ?? ""
        let calle  = p.thoroughfare ?? ""
        let cp     = p.postalCode ?? ""
        let ciudad = p.locality ?? p.administrativeArea ?? ""

        let linea1 = [calle, numero].filter { !$0.isEmpty }.joined(separator: " ")
        let linea2 = [cp, ciudad].filter { !$0.isEmpty }.joined(separator: " ")
        return [linea1, linea2].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func tarjetaItem(_ item: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icono(para: item))
                    .font(.title2)
                    .foregroundStyle(.red)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name ?? "Selected location")
                        .font(.headline)

                    let partes = [
                        item.placemark.thoroughfare,
                        item.placemark.locality,
                        item.placemark.country
                    ].compactMap { $0 }.joined(separator: ", ")
                    if !partes.isEmpty {
                        Text(partes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                // Deselect
                Button {
                    selectedItem = nil
                    featureSeleccionada = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            // Extra info
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

            // Action button
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
