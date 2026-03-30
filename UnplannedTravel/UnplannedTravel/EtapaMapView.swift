import SwiftUI
import MapKit

struct EtapaMapView: View {
    let etapa: Etapa
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Map(initialPosition: camaraInicial) {
                ForEach(anotaciones) { punto in
                    Annotation(punto.nombre, coordinate: punto.coordenada, anchor: .bottom) {
                        VStack(spacing: 0) {
                            Image(systemName: etapa.tipo.icono)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.accentColor)
                                .offset(y: -2)
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .all))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .navigationTitle(etapa.etiqueta)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        abrirEnMapas()
                    } label: {
                        Label("Abrir en Mapas", systemImage: "arrow.triangle.turn.up.right.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                infoPanel
            }
        }
    }

    // MARK: - Info panel

    @ViewBuilder
    private var infoPanel: some View {
        VStack(spacing: 0) {
            ForEach(anotaciones) { punto in
                HStack(spacing: 12) {
                    Image(systemName: punto.sistemaIcono)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(punto.nombre)
                            .font(.subheadline).bold()
                        if !punto.detalle.isEmpty {
                            Text(punto.detalle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                if punto.id != anotaciones.last?.id {
                    Divider().padding(.leading)
                }
            }
        }
        .background(.regularMaterial)
    }

    // MARK: - Data

    private struct Punto: Identifiable {
        let id: String
        let nombre: String
        let detalle: String
        let coordenada: CLLocationCoordinate2D
        let sistemaIcono: String
    }

    private var anotaciones: [Punto] {
        var result: [Punto] = []
        if etapa.tipo.esTransporte {
            if let d = etapa.origen, d.tieneCoordenadas {
                result.append(Punto(
                    id: "origen",
                    nombre: d.descripcion.isEmpty ? (d.ciudad.isEmpty ? "Origen" : d.ciudad) : d.descripcion,
                    detalle: [d.ciudad, d.pais].filter { !$0.isEmpty }.joined(separator: ", "),
                    coordenada: CLLocationCoordinate2D(latitude: d.latitud!, longitude: d.longitud!),
                    sistemaIcono: "arrow.up.right.circle"
                ))
            }
            if let d = etapa.destino, d.tieneCoordenadas {
                result.append(Punto(
                    id: "destino",
                    nombre: d.descripcion.isEmpty ? (d.ciudad.isEmpty ? "Destino" : d.ciudad) : d.descripcion,
                    detalle: [d.ciudad, d.pais].filter { !$0.isEmpty }.joined(separator: ", "),
                    coordenada: CLLocationCoordinate2D(latitude: d.latitud!, longitude: d.longitud!),
                    sistemaIcono: "arrow.down.left.circle"
                ))
            }
        } else if let d = etapa.direccion, d.tieneCoordenadas {
            result.append(Punto(
                id: "lugar",
                nombre: d.descripcion.isEmpty ? (d.ciudad.isEmpty ? etapa.tipo.nombre : d.ciudad) : d.descripcion,
                detalle: [d.ciudad, d.pais].filter { !$0.isEmpty }.joined(separator: ", "),
                coordenada: CLLocationCoordinate2D(latitude: d.latitud!, longitude: d.longitud!),
                sistemaIcono: "mappin.circle"
            ))
        }
        return result
    }

    // MARK: - Camera

    private var camaraInicial: MapCameraPosition {
        guard !anotaciones.isEmpty else { return .automatic }
        if anotaciones.count == 1 {
            return .region(MKCoordinateRegion(
                center: anotaciones[0].coordenada,
                latitudinalMeters: 800,
                longitudinalMeters: 800
            ))
        }
        let lats = anotaciones.map(\.coordenada.latitude)
        let lons = anotaciones.map(\.coordenada.longitude)
        let centro = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.6 + 0.02,
            longitudeDelta: (lons.max()! - lons.min()!) * 1.6 + 0.02
        )
        return .region(MKCoordinateRegion(center: centro, span: span))
    }

    // MARK: - Apple Maps

    private func abrirEnMapas() {
        let items = anotaciones.map { punto -> MKMapItem in
            let placemark = MKPlacemark(coordinate: punto.coordenada)
            let item = MKMapItem(placemark: placemark)
            item.name = punto.nombre
            return item
        }
        if items.count == 2 {
            MKMapItem.openMaps(with: items, launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
            ])
        } else {
            items.first?.openInMaps()
        }
    }
}
