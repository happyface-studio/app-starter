import CoreLocation
import Foundation
import MapboxMaps
import UIKit

/// Area covered by the baked toy-city model (ios/tools/bake_city.py, CLIP ±560 m × ±480 m).
enum Altstadt {
    static let origin = CLLocationCoordinate2D(latitude: 50.1104, longitude: 8.6835)
    static let west = 8.675655, east = 8.691345, south = 50.106088, north = 50.114712

    /// `["!", ["within", polygon]]` — keeps simple extrusions out of the baked area.
    static let outsideFilter: Exp = {
        let ring = "[[\(west),\(south)],[\(east),\(south)],[\(east),\(north)],[\(west),\(north)],[\(west),\(south)]]"
        let json = """
        ["all", ["==", ["get", "extrude"], "true"], ["!", ["within", {"type": "Polygon", "coordinates": [\(ring)]}]]]
        """
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(Exp.self, from: Data(json.utf8))
    }()
}

/// Our stylised buildings for the Altstadt: one baked model anchored at `Altstadt.origin`.
struct ToyBuildings: MapStyleContent {
    var body: some MapStyleContent {
        if let url = exploreBundle.url(forResource: "altstadt_buildings", withExtension: "glb") {
            Model(id: "altstadt-buildings", uri: url)

            GeoJSONSource(id: "altstadt-anchor")
                .data(.geometry(.point(Point(Altstadt.origin))))

            ModelLayer(id: "altstadt-buildings", source: "altstadt-anchor")
                .slot(.middle)
                .modelId("altstadt-buildings")
                .modelType(.common3d)
                .modelScale(x: 1, y: 1, z: 1)
                .modelCastShadows(true)
                .modelReceiveShadows(true)
                .modelAmbientOcclusionIntensity(1)
                .modelRoughness(0.95)
        }
    }
}

/// Everything outside the baked area: simple cream extrusions so the city doesn't end at the edge.
struct FarBuildings: MapStyleContent {
    var body: some MapStyleContent {
        VectorSource(id: "far-buildings")
            .url("mapbox://mapbox.mapbox-streets-v8")

        FillExtrusionLayer(id: "far-buildings", source: "far-buildings")
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(13)
            .filter(Altstadt.outsideFilter)
            .fillExtrusionColor(UIColor(hex: 0xEBD3A6))
            .fillExtrusionHeight(Exp(.get) { "height" })
            .fillExtrusionBase(Exp(.get) { "min_height" })
            .fillExtrusionAmbientOcclusionIntensity(0.4)
            .fillExtrusionOpacity(1)
    }
}
