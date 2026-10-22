import MapboxMaps

/// Shopfronts with striped awnings and warm windows, café tables, benches, bike racks and rental
/// docks, and rows of parked cars (data baked by `ios/tools/bake_street_detail.py`).
struct StreetDetail: MapStyleContent {
    private static let source = "street-detail"

    private static func toy(_ z16: Double, _ z18: Double) -> Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            16
            [z16, z16, z16]
            18
            [z18, z18, z18]
        }
    }

    private static var fadeIn: Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            15.8
            0
            16.4
            1
        }
    }

    private static func kind(_ k: String) -> Exp {
        Exp(.eq) { Exp(.get) { "kind" }; k }
    }

    private static func modelId(_ model: String?) -> Exp {
        guard let model else { return Exp(.get) { "m" } }
        return Exp(.toString) { model }
    }

    private func layer(_ id: String, kind: String, model: String?, scale: Exp, minZoom: Double = 15.8) -> ModelLayer {
        ModelLayer(id: id, source: Self.source)
            .slot(.middle)
            .minZoom(minZoom)
            .filter(Self.kind(kind))
            .modelId(Self.modelId(model))
            .modelType(.common3d)
            .modelScale(scale)
            .modelRotation(Exp(.get) { "r" })
            .modelOpacity(Self.fadeIn)
            .modelCastShadows(true)
            .modelReceiveShadows(true)
    }

    var body: some MapStyleContent {
        if let url = exploreBundle.url(forResource: "frankfurt_detail", withExtension: "geojson") {
            GeoJSONSource(id: Self.source).data(.url(url))

            Model(id: "awning_red", uri: PuffyTrees.model("awning_red"))
            Model(id: "awning_green", uri: PuffyTrees.model("awning_green"))
            Model(id: "awning_navy", uri: PuffyTrees.model("awning_navy"))
            Model(id: "awning_mustard", uri: PuffyTrees.model("awning_mustard"))
            Model(id: "shop_glow", uri: PuffyTrees.model("shop_glow"))
            Model(id: "cafe_set", uri: PuffyTrees.model("cafe_set"))
            Model(id: "bench", uri: PuffyTrees.model("bench"))
            Model(id: "bike_rack", uri: PuffyTrees.model("bike_rack"))
            Model(id: "bike_dock", uri: PuffyTrees.model("bike_dock"))

            layer("parked-cars", kind: "parked", model: nil, scale: Self.toy(1.5, 1.2))
            layer("shopfronts", kind: "shop", model: nil, scale: Self.toy(1.3, 1.15))
            layer("shop-windows", kind: "shop", model: "shop_glow", scale: Self.toy(1.3, 1.15))
                .modelCastShadows(false)
                // Warm and bright after dark, a soft lit-shop glow by day.
                .modelEmissiveStrength(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.measureLight) { "brightness" }
                    0.1
                    1.4
                    0.4
                    0.35
                })
            layer("cafe-tables", kind: "cafe", model: "cafe_set", scale: Self.toy(1.4, 1.2), minZoom: 16.2)
            layer("benches", kind: "bench", model: "bench", scale: Self.toy(1.6, 1.3), minZoom: 16.4)
            layer("bike-racks", kind: "bikes", model: "bike_rack", scale: Self.toy(1.5, 1.25), minZoom: 16.4)
            layer("bike-docks", kind: "dock", model: "bike_dock", scale: Self.toy(1.5, 1.25), minZoom: 16.2)
        }
    }
}
