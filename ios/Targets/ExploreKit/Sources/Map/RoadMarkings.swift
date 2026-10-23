import MapboxMaps
import UIKit

/// Painted markings: dashed white centre lines and solid edge lines on main roads (from Streets
/// v8), and red bike lanes along the kerb where OSM maps them (`ios/tools/bake_markings.py`).
/// Widths and offsets follow Standard's drawn road widths (`RoadWidth`).
struct RoadMarkings: MapStyleContent {
    private static let source = "road-markings"
    private static let mainRoads = ["trunk", "primary", "secondary", "tertiary"]

    private static var fadeIn: Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            15.5
            0
            16
            1
        }
    }

    private static var mainFilter: Exp {
        Exp(.all) {
            Exp(.match) { Exp(.get) { "class" }; mainRoads; true; false }
            Exp(.match) { Exp(.get) { "structure" }; ["none", "ford"]; true; false }
            Exp(.eq) { Exp(.geometryType); "LineString" }
        }
    }

    private static let paint = StyleColor(UIColor(white: 1, alpha: 0.78))
    private static let bike = StyleColor(UIColor(hex: 0xC25B4C))

    private func edge(_ side: Double) -> LineLayer {
        LineLayer(id: "road-edge-\(side > 0 ? "r" : "l")", source: Self.source)
            .sourceLayer("road")
            .slot(.middle)
            .minZoom(15.5)
            .filter(Self.mainFilter)
            .lineColor(Self.paint)
            .lineWidth(RoadWidth.exp { 0.035 * $0 + 0.3 })
            .lineOffset(RoadWidth.exp { side * (0.5 * $0 - 0.09 * $0 - 0.4) })
            .lineOpacity(Self.fadeIn)
    }

    private func bikeLane(_ side: Double) -> LineLayer {
        LineLayer(id: "bike-lane-\(side > 0 ? "r" : "l")", source: "bike-lanes")
            .slot(.middle)
            .minZoom(15.5)
            .filter(Exp(.eq) { Exp(.get) { "s" }; side })
            .lineColor(Self.bike)
            .lineWidth(RoadWidth.exp { 0.15 * $0 })
            .lineOffset(RoadWidth.exp { side * (0.5 * $0 - 0.13 * $0) })
            .lineOpacity(Exp(.interpolate) {
                Exp(.linear)
                Exp(.zoom)
                15.5
                0
                16
                0.85
            })
    }

    var body: some MapStyleContent {
        VectorSource(id: Self.source)
            .url("mapbox://mapbox.mapbox-streets-v8")

        LineLayer(id: "road-centre-line", source: Self.source)
            .sourceLayer("road")
            .slot(.middle)
            .minZoom(15.5)
            .filter(Exp(.all) { Self.mainFilter; Exp(.neq) { Exp(.get) { "oneway" }; "true" } })
            .lineColor(Self.paint)
            .lineWidth(RoadWidth.exp { 0.04 * $0 + 0.3 })
            .lineDasharray([4, 5])
            .lineOpacity(Self.fadeIn)

        edge(1)
        edge(-1)

        if let url = exploreBundle.url(forResource: "frankfurt_markings", withExtension: "geojson") {
            GeoJSONSource(id: "bike-lanes").data(.url(url))
            bikeLane(1)
            bikeLane(-1)
        }
    }
}
