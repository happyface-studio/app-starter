import MapboxMaps
import UIKit

/// Subtle surface texture laid over Standard's street colours: setts on pedestrian zones,
/// paving slabs on footpaths, fine grain on roads. Textures are alpha-only (see
/// `ios/tools/make_street_textures.py`), so they work with every palette.
///
/// Patterns can't reach into the imported basemap's layers, so these read their own copy of
/// Streets v8 and mirror Standard's filters and widths.
struct StreetTextures: MapStyleContent {
    private static let source = "street-textures"

    private static func image(_ name: String) -> UIImage? {
        UIImage(named: name, in: exploreBundle, with: nil)
    }

    private static var fadeIn: Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            15
            0
            16
            1
        }
    }

    private static func classIn(_ classes: [String]) -> Exp {
        Exp(.match) {
            Exp(.get) { "class" }
            classes
            true
            false
        }
    }

    private static func geometry(_ type: String) -> Exp {
        Exp(.eq) { Exp(.geometryType); type }
    }

    private static let atGrade = Exp(.match) {
        Exp(.get) { "structure" }
        ["none", "ford"]
        true
        false
    }

    /// Standard's footway width.
    private static var footwayWidth: Exp {
        Exp(.interpolate) {
            Exp(.exponential) { 1.5 }
            Exp(.zoom)
            12
            0
            18
            6
            22
            80
        }
    }

    private static let roadClasses = RoadWidth.drivable
    private static var roadWidth: Exp { RoadWidth.exp() }

    var body: some MapStyleContent {
        if let cobbles = Self.image("tex_cobbles"), let slabs = Self.image("tex_slabs"), let grain = Self.image("tex_grain") {
            StyleImage(id: "tex-cobbles", image: cobbles)
            StyleImage(id: "tex-slabs", image: slabs)
            StyleImage(id: "tex-grain", image: grain)

            VectorSource(id: Self.source)
                .url("mapbox://mapbox.mapbox-streets-v8")

            LineLayer(id: "tex-roads", source: Self.source)
                .sourceLayer("road")
                .slot(.middle)
                .minZoom(15)
                .filter(Exp(.all) { Self.classIn(Self.roadClasses); Self.atGrade; Self.geometry("LineString") })
                .lineCap(.round)
                .lineJoin(.round)
                .linePattern("tex-grain")
                .lineWidth(Self.roadWidth)
                .lineOpacity(Self.fadeIn)

            FillLayer(id: "tex-plazas", source: Self.source)
                .sourceLayer("road")
                .slot(.middle)
                .minZoom(15)
                .filter(Exp(.all) { Self.classIn(["path", "pedestrian"]); Self.atGrade; Self.geometry("Polygon") })
                .fillPattern("tex-cobbles")
                .fillOpacity(Self.fadeIn)

            LineLayer(id: "tex-pedestrian", source: Self.source)
                .sourceLayer("road")
                .slot(.middle)
                .minZoom(15)
                .filter(Exp(.all) { Self.classIn(["pedestrian"]); Self.atGrade; Self.geometry("LineString") })
                .lineCap(.round)
                .lineJoin(.round)
                .linePattern("tex-cobbles")
                .lineWidth(Self.footwayWidth)
                .lineOpacity(Self.fadeIn)

            LineLayer(id: "tex-paths", source: Self.source)
                .sourceLayer("road")
                .slot(.middle)
                .minZoom(15)
                .filter(Exp(.all) { Self.classIn(["path"]); Self.atGrade; Self.geometry("LineString") })
                .lineCap(.round)
                .lineJoin(.round)
                .linePattern("tex-slabs")
                .lineWidth(Self.footwayWidth)
                .lineOpacity(Self.fadeIn)
        }
    }
}
