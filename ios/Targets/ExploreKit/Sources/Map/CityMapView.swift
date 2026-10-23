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
    private let basemap = Basemap.shared

    var body: some View {
        if basemap.isResolved || LandmarkMask.isEnabled {
            map
        } else {
            Color(UIColor(hex: 0xF2EADF)).ignoresSafeArea()
        }
    }

    private var map: some View {
        MapReader { proxy in
        Map(viewport: $viewport) {
            if LandmarkMask.isEnabled {
            } else if UserDefaults.standard.bool(forKey: "bakedAltstadt") {
                ToyBuildings()
            } else if UserDefaults.standard.bool(forKey: "toyExtrusions") {
                CityBuildings()
            } else if LookTest.pastelBlocks {
                PastelBlocks()
            }
            if !LandmarkMask.isEnabled {
                Yards(palette: store.renderPalette)
                GroundTextures(palette: store.renderPalette)
                Kerbs(palette: store.renderPalette)
                FacadeTile(palette: store.renderPalette)
                if !UserDefaults.standard.bool(forKey: "standardPlain") {
                    PlainBuildings(palette: store.renderPalette)
                }
                StreetTextures()
                CloudShadows(mood: store.mood, sky: LiveConditions.shared.sky)
                PuffyTrees(season: LiveConditions.shared.season)
                StreetFurniture(mood: store.mood)
                StreetDetail()
                Traffic(mood: store.mood)
                LivingLayers()
                WeatherEffects(sky: LiveConditions.shared.sky)
            }

            ForEvery(LandmarkMask.isEnabled ? [] : store.visiblePlaces) { place in
                MapViewAnnotation(coordinate: place.coordinate) {
                    SpotMarker(place: place, isSelected: store.selection == .place(place.id))
                        .onTapGesture { select(.place(place.id)) }
                }
                .allowOverlap(true)
                .variableAnchors([ViewAnnotationAnchorConfig(anchor: .left)])
                .priority(store.selection == .place(place.id) ? 10 : (place.isSaved ? 2 : 1))
            }

            ForEvery(LandmarkMask.isEnabled ? [] : store.visibleEvents) { event in
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
        .mapStyle(LandmarkMask.isEnabled ? LandmarkMask.style : CityStyle.mapStyle(
            for: store.mood,
            palette: store.renderPalette,
            basemap: UserDefaults.standard.bool(forKey: "plainStandard") ? nil : basemap.json(for: store.renderPalette)))
        .ornamentOptions(
            OrnamentOptions(
                scaleBar: ScaleBarViewOptions(visibility: .hidden),
                compass: CompassViewOptions(visibility: .hidden)
            )
        )
        .additionalSafeAreaInsets(.bottom, bottomInset)
        .onStyleLoaded { _ in
            CloudDrift.shared.styleLoaded()
            LivingCity.shared.styleLoaded()
            TrafficSim.shared.styleLoaded()
            // `-hide layer1,layer2` hides layers (performance bisecting).
            if let map = proxy.map, let hide = UserDefaults.standard.string(forKey: "hide") {
                for id in hide.split(separator: ",") {
                    try? map.setLayerProperty(for: String(id), property: "visibility", value: "none")
                }
            }
        }
        .onMapLoaded { _ in
            WaterDrift.shared.start(map: proxy.map)
            TrafficSim.shared.start(map: proxy.map)
            CloudDrift.shared.start(map: proxy.map)
            LivingCity.shared.start(map: proxy.map)
            // Performance check: `-perfOrbit YES` slowly turns the camera half a circle.
            if UserDefaults.standard.bool(forKey: "perfOrbit"), let camera = proxy.camera, let map = proxy.map {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    camera.ease(to: CameraOptions(bearing: map.cameraState.bearing + 180), duration: 12)
                }
            }
            if LandmarkMask.isEnabled {
                LandmarkMask.run(proxy: proxy)
            } else if LandmarkDump.isEnabled, let map = proxy.map {
                LandmarkDump.run(map: map) { opts in map.setCamera(to: opts) }
            }
        }
        .onMapTapGesture { _ in
            if store.selection != nil { store.selection = nil }
        }
        .ignoresSafeArea()
        }
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

    /// `-camera lat,lon,zoom[,bearing]` starts somewhere else (look tests).
    static var initialViewport: Viewport {
        let v = (UserDefaults.standard.string(forKey: "camera") ?? "").split(separator: ",").compactMap { Double($0) }
        if v.count >= 3 {
            return .camera(center: CLLocationCoordinate2D(latitude: v[0], longitude: v[1]), zoom: v[2],
                           bearing: v.count > 3 ? v[3] : -18, pitch: 58)
        }
        return .camera(center: Frankfurt.center, zoom: 16.9, bearing: -18, pitch: 58)
    }
}
