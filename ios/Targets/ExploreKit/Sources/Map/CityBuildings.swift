@_spi(Experimental) import MapboxMaps
import UIKit

/// Toy-style buildings for the whole map, built at runtime from Mapbox's own building
/// footprints (streets-v8), so they never run out and always line up with the map:
/// cream walls plus a slate-blue cap with rounded edges that reads as a soft sloped roof.
/// Standard's own 3D buildings are switched off; its hand-made landmark models stay.
struct CityBuildings: MapStyleContent {
    static let source = "city-buildings"
    static let roofDepth = 2.4

    var body: some MapStyleContent {
        VectorSource(id: Self.source)
            .url("mapbox://mapbox.mapbox-streets-v8")

        FillExtrusionLayer(id: "city-walls", source: Self.source)
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(13)
            .filter(Exp(.eq) { Exp(.get) { "extrude" }; "true" })
            .fillExtrusionColor(Exp(.match) {
                Exp(.modulo) { Exp(.id); 4 }
                0; UIColor(hex: 0xF2DDB4)
                1; UIColor(hex: 0xE9C99A)
                2; UIColor(hex: 0xF5E8D2)
                UIColor(hex: 0xEED3A8)
            })
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
            .fillExtrusionColor(UIColor(hex: 0x6876BE))
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
