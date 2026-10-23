import MapboxMaps
import UIKit

/// Trees in back gardens and courtyards (data baked by `ios/tools/bake_yards.py`). Lawn, hedge and
/// paving fills for the yards were tried and dropped: they read as flat green blobs.
struct Yards: MapStyleContent {
    var palette: CityPalette

    private static let source = "yards"

    private static func kind(_ k: String) -> Exp {
        Exp(.eq) { Exp(.get) { "k" }; k }
    }

    private static var fadeIn: Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            13.5
            0
            14.5
            1
        }
    }


    var body: some MapStyleContent {
        if let url = exploreBundle.url(forResource: "frankfurt_yards", withExtension: "geojson") {
            GeoJSONSource(id: Self.source).data(.url(url))

            ModelLayer(id: "yard-trees", source: Self.source)
                .slot(.middle)
                .minZoom(15.5)
                .filter(Self.kind("tree"))
                .modelId(Exp(.get) { "m" })
                .modelType(.common3d)
                .modelScale(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.zoom)
                    15.5
                    [1.4, 1.4, 1.4]
                    18
                    [1.05, 1.05, 1.05]
                })
                .modelCastShadows(true)
                .modelReceiveShadows(true)
                .modelOpacity(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.zoom)
                    15.5
                    0
                    16
                    1
                })
        }
    }
}
