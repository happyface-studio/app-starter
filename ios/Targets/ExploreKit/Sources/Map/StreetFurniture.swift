import MapboxMaps
import UIKit

/// Street lamps and traffic lights (data baked by `ios/tools/bake_street_furniture.py`).
/// Lantern glass and signal lenses are separate models so only they glow.
struct StreetFurniture: MapStyleContent {
    var mood: MapMood

    private static let source = "street-furniture"

    /// Mapbox has no bloom, so lamps get a soft warm pool on the ground once it's dark.
    private var poolOpacity: Double {
        switch mood {
        case .day: 0
        case .dawn: 0.25
        case .dusk: 0.4
        case .night: 0.6
        }
    }

    private static var scale: Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            15.5
            [1.4, 1.4, 1.4]
            18
            [1.05, 1.05, 1.05]
        }
    }

    private static var fadeIn: Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            15.5
            0
            16.2
            1
        }
    }

    private static func kind(_ k: String) -> Exp {
        Exp(.eq) { Exp(.get) { "kind" }; k }
    }

    var body: some MapStyleContent {
        if let url = exploreBundle.url(forResource: "frankfurt_street", withExtension: "geojson") {
            GeoJSONSource(id: Self.source).data(.url(url))

            Model(id: "lamp_post", uri: PuffyTrees.model("lamp_post"))
            Model(id: "lamp_glow", uri: PuffyTrees.model("lamp_glow"))
            Model(id: "signal_body", uri: PuffyTrees.model("signal_body"))
            Model(id: "signal_red", uri: PuffyTrees.model("signal_red"))
            Model(id: "signal_green", uri: PuffyTrees.model("signal_green"))

            CircleLayer(id: "street-lamp-pools", source: Self.source)
                .slot(.middle)
                .minZoom(15)
                .filter(Self.kind("lamp"))
                .circlePitchAlignment(.map)
                .circleColor(StyleColor(UIColor(hex: 0xFFD08A)))
                .circleBlur(1)
                .circleRadius(Exp(.interpolate) {
                    Exp(.exponential) { 2 }
                    Exp(.zoom)
                    15
                    3
                    18
                    26
                    20
                    104
                })
                .circleOpacity(poolOpacity)
                .circleEmissiveStrength(1)

            ModelLayer(id: "street-lamps", source: Self.source)
                .slot(.middle)
                .minZoom(15.5)
                .filter(Self.kind("lamp"))
                .modelId("lamp_post")
                .modelType(.common3d)
                .modelScale(Self.scale)
                .modelRotation(Exp(.get) { "r" })
                .modelOpacity(Self.fadeIn)
                .modelCastShadows(true)
                .modelReceiveShadows(true)

            ModelLayer(id: "street-lamp-glow", source: Self.source)
                .slot(.middle)
                .minZoom(15.5)
                .filter(Self.kind("lamp"))
                .modelId("lamp_glow")
                .modelType(.common3d)
                .modelScale(Self.scale)
                .modelRotation(Exp(.get) { "r" })
                .modelOpacity(Self.fadeIn)
                .modelCastShadows(false)
                // Bright at night, a soft milky glass by day.
                .modelEmissiveStrength(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.measureLight) { "brightness" }
                    0.1
                    1.6
                    0.4
                    0.25
                })

            ModelLayer(id: "signals", source: Self.source)
                .slot(.middle)
                .minZoom(15.5)
                .filter(Self.kind("signal"))
                .modelId("signal_body")
                .modelType(.common3d)
                .modelScale(Self.scale)
                .modelRotation(Exp(.get) { "r" })
                .modelOpacity(Self.fadeIn)
                .modelCastShadows(true)

            ModelLayer(id: "signal-lights", source: Self.source)
                .slot(.middle)
                .minZoom(15.5)
                .filter(Self.kind("signal"))
                .modelId(Exp(.concat) { "signal_"; Exp(.get) { "lit" } })
                .modelType(.common3d)
                .modelScale(Self.scale)
                .modelRotation(Exp(.get) { "r" })
                .modelOpacity(Self.fadeIn)
                .modelCastShadows(false)
                .modelEmissiveStrength(1.2)
        }
    }
}
