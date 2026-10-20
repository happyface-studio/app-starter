@_spi(Experimental) import MapboxMaps
import UIKit

/// Toy-style buildings for the whole map, built at runtime from Mapbox's own building
/// footprints (streets-v8), so they never run out and always line up with the map:
/// cream walls plus a slate-blue cap with rounded edges that reads as a soft sloped roof.
/// Standard's own 3D buildings are switched off; its hand-made landmark models stay.
struct CityBuildings: MapStyleContent {
    static let source = "city-buildings"
    static let roofDepth = 2.4

    /// One floor-high window tile for the walls (fill-extrusion-pattern needs power-of-two sizes).
    static let windowTile: UIImage = {
        let size = CGSize(width: 32, height: 32)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 2
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor(hex: 0xF0DAB0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(hex: 0xFBF4E6).setFill()
            ctx.fill(CGRect(x: 9, y: 6, width: 14, height: 20))
            UIColor(hex: 0x6074B8).setFill()
            ctx.fill(CGRect(x: 11, y: 8, width: 10, height: 16))
            UIColor(hex: 0xFBF4E6).setFill()
            ctx.fill(CGRect(x: 15.25, y: 8, width: 1.5, height: 16))
        }
    }()

    var body: some MapStyleContent {
        StyleImage(id: "toy-window", image: Self.windowTile)

        VectorSource(id: Self.source)
            .url("mapbox://mapbox.mapbox-streets-v8")

        FillExtrusionLayer(id: "city-walls", source: Self.source)
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(13)
            .filter(Exp(.eq) { Exp(.get) { "extrude" }; "true" })
            .fillExtrusionColor(Exp(.match) {
                Exp(.mod) { Exp(.id); 4 }
                0; UIColor(hex: 0xF2DDB4)
                1; UIColor(hex: 0xE9C99A)
                2; UIColor(hex: 0xF5E8D2)
                UIColor(hex: 0xEED3A8)
            })
            .fillExtrusionPattern("toy-window")
            .fillExtrusionBase(Exp(.get) { "min_height" })
            .fillExtrusionHeight(Exp(.max) {
                Exp(.sum) { Exp(.get) { "min_height" }; 1 }
                Exp(.sum) { Exp(.get) { "height" }; -Self.roofDepth }
            })
            .fillExtrusionVerticalGradient(false)
            .fillExtrusionAmbientOcclusionIntensity(0.55)
            .fillExtrusionAmbientOcclusionRadius(4)
            .fillExtrusionCastShadows(true)
            .fillExtrusionOpacity(Exp(.interpolate) { Exp(.linear); Exp(.zoom); 13; 0; 14; 1 })

        FillExtrusionLayer(id: "city-roofs", source: Self.source)
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(13)
            .filter(Exp(.eq) { Exp(.get) { "extrude" }; "true" })
            .fillExtrusionColor(UIColor(hex: 0x7380C2))
            .fillExtrusionBase(Exp(.max) {
                Exp(.sum) { Exp(.get) { "min_height" }; 1 }
                Exp(.sum) { Exp(.get) { "height" }; -Self.roofDepth }
            })
            .fillExtrusionHeight(Exp(.max) {
                Exp(.sum) { Exp(.get) { "min_height" }; 2 }
                Exp(.get) { "height" }
            })
            .fillExtrusionEdgeRadius(0.85)
            .fillExtrusionRoundedRoof(true)
            .fillExtrusionVerticalGradient(false)
            .fillExtrusionAmbientOcclusionIntensity(0.3)
            .fillExtrusionCastShadows(true)
            .fillExtrusionOpacity(Exp(.interpolate) { Exp(.linear); Exp(.zoom); 13; 0; 14; 1 })
    }
}
