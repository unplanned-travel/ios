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
                        Label("Open in Maps", systemImage: "arrow.triangle.turn.up.right.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
        let radioMetros: Double?
    }

    private func punto(id: String, dir: Direccion, icono: String) -> Punto {
        Punto(
            id: id,
            nombre: dir.descripcion.isEmpty ? (dir.ciudad.isEmpty ? id : dir.ciudad) : dir.descripcion,
            detalle: dir.direccionCompleta.isEmpty
                ? [dir.ciudad, dir.pais].filter { !$0.isEmpty }.joined(separator: ", ")
                : dir.direccionCompleta,
            coordenada: CLLocationCoordinate2D(latitude: dir.latitud!, longitude: dir.longitud!),
            sistemaIcono: icono,
            radioMetros: dir.radioMetros
        )
    }

    private var anotaciones: [Punto] {
        var result: [Punto] = []
        if etapa.tipo.esTransporte {
            if let d = etapa.origen, d.tieneCoordenadas {
                result.append(punto(id: "origen", dir: d, icono: "arrow.up.right.circle"))
            }
            if let d = etapa.destino, d.tieneCoordenadas {
                result.append(punto(id: "destino", dir: d, icono: "arrow.down.left.circle"))
            }
        } else if let d = etapa.direccion, d.tieneCoordenadas {
            result.append(punto(id: "lugar", dir: d, icono: "mappin.circle"))
        }
        return result
    }

    // MARK: - Camera

    private static let radioDefecto: Double = 400

    private var camaraInicial: MapCameraPosition {
        guard !anotaciones.isEmpty else { return .automatic }
        if anotaciones.count == 1, let p = anotaciones.first {
            let radio = p.radioMetros ?? Self.radioDefecto
            return .region(MKCoordinateRegion(
                center: p.coordenada,
                latitudinalMeters: radio,
                longitudinalMeters: radio
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
