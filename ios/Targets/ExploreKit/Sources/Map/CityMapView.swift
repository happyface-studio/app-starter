import CoreLocation
import MapboxMaps
import SwiftUI

enum Frankfurt {
    static let center = CLLocationCoordinate2D(latitude: 50.1112, longitude: 8.6822)
}

struct CityMapView: View {
    @Bindable var store: ExploreStore
    @Binding var viewport: Viewport
    var bottomInset: CGFloat

    var body: some View {
        Map(viewport: $viewport) {
            FarBuildings()
            SlateRoofs()
            ToyBuildings()
            PuffyTrees()

            ForEvery(store.visiblePlaces) { place in
                MapViewAnnotation(coordinate: place.coordinate) {
                    SpotMarker(place: place, isSelected: store.selection == .place(place.id))
                        .onTapGesture { select(.place(place.id)) }
                }
                .allowOverlap(true)
                .variableAnchors([ViewAnnotationAnchorConfig(anchor: .left)])
                .priority(store.selection == .place(place.id) ? 10 : (place.isSaved ? 2 : 1))
            }

            ForEvery(store.visibleEvents) { event in
                MapViewAnnotation(coordinate: event.coordinate) {
                    EventMarker(event: event, isSelected: store.selection == .event(event.id))
                        .onTapGesture { select(.event(event.id)) }
                }
                .allowOverlap(true)
                .variableAnchors([ViewAnnotationAnchorConfig(anchor: .bottom)])
                .priority(store.selection == .event(event.id) ? 10 : 3)
            }

            if store.showsUserLocation {
                Puck2D(bearing: .heading)
            }
        }
        .mapStyle(CityStyle.mapStyle(for: store.mood))
        .ornamentOptions(
            OrnamentOptions(
                scaleBar: ScaleBarViewOptions(visibility: .hidden),
                compass: CompassViewOptions(visibility: .hidden)
            )
        )
        .additionalSafeAreaInsets(.bottom, bottomInset)
        .onMapTapGesture { _ in
            if store.selection != nil { store.selection = nil }
        }
        .ignoresSafeArea()
        .onChange(of: store.selection) { _, selection in
            guard let selection else { return }
            let coordinate: CLLocationCoordinate2D? =
                switch selection {
                case .place(let id): store.places.first { $0.id == id }?.coordinate
                case .event(let id): store.events.first { $0.id == id }?.coordinate
                }
            guard let coordinate else { return }
            withViewportAnimation(.fly(duration: 1.1)) {
                viewport = .camera(center: coordinate, zoom: 17.2, bearing: -18, pitch: store.is3D ? 58 : 0)
            }
        }
        .onChange(of: store.is3D) { _, is3D in
            withViewportAnimation(.easeInOut(duration: 0.7)) {
                viewport = .camera(center: Frankfurt.center, zoom: is3D ? 16.9 : 14.6, bearing: is3D ? -18 : 0, pitch: is3D ? 58 : 0)
            }
        }
    }

    private func select(_ selection: Selection) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        store.selection = selection
    }

    static var initialViewport: Viewport {
        .camera(center: Frankfurt.center, zoom: 16.9, bearing: -18, pitch: 58)
    }
}
