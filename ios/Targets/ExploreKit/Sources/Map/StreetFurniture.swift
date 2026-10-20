import MapboxMaps

/// Street lamps and traffic lights (data baked by `ios/tools/bake_street_furniture.py`).
/// Lantern glass and signal lenses are separate models so only they glow.
struct StreetFurniture: MapStyleContent {
    private static let source = "street-furniture"

    private static var scale: Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            15.5
            [1.9, 1.9, 1.9]
            18
            [1.4, 1.4, 1.4]
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
