import MapboxMaps
import UIKit

/// Back gardens, paved courtyards and car parks (data baked by `ios/tools/bake_yards.py`), so the
/// ground between streets and houses isn't bare sand. Drawn in the `bottom` slot: under roads,
/// kerbs and buildings, which cover everything but the yards themselves.
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

    private var lawn: UIColor { UIColor(hex: palette.green).blended(with: UIColor(hex: palette.land), amount: 0.3) }
    private var hedge: UIColor { UIColor(hex: palette.green).blended(with: UIColor(hex: 0x3F5A2A), amount: 0.45) }
    private var yard: UIColor { UIColor(hex: palette.paving).blended(with: UIColor(hex: palette.land), amount: 0.45) }
    private var asphalt: UIColor { UIColor(hex: palette.roads).blended(with: UIColor(hex: 0x9A9AA2), amount: 0.4) }

    var body: some MapStyleContent {
        if let url = exploreBundle.url(forResource: "frankfurt_yards", withExtension: "geojson") {
            GeoJSONSource(id: Self.source).data(.url(url))

            FillLayer(id: "yards-paved", source: Self.source)
                .slot(.bottom)
                .minZoom(13.5)
                .filter(Self.kind("paved"))
                .fillColor(StyleColor(yard))
                .fillOpacity(Self.fadeIn)

            FillLayer(id: "yards-paved-tex", source: Self.source)
                .slot(.bottom)
                .minZoom(15)
                .filter(Self.kind("paved"))
                .fillPattern("tex-slabs")
                .fillOpacity(0.6)

            FillLayer(id: "yards-parking", source: Self.source)
                .slot(.bottom)
                .minZoom(13.5)
                .filter(Self.kind("parking"))
                .fillColor(StyleColor(asphalt))
                .fillOpacity(Self.fadeIn)

            FillLayer(id: "yards-parking-tex", source: Self.source)
                .slot(.bottom)
                .minZoom(15)
                .filter(Self.kind("parking"))
                .fillPattern("tex-grain")

            FillLayer(id: "yards-garden", source: Self.source)
                .slot(.bottom)
                .minZoom(13.5)
                .filter(Self.kind("garden"))
                .fillColor(StyleColor(lawn))
                .fillOpacity(Self.fadeIn)

            FillLayer(id: "yards-garden-tex", source: Self.source)
                .slot(.bottom)
                .minZoom(14)
                .filter(Self.kind("garden"))
                .fillPattern("tex-grass")

            // A clipped hedge round every garden.
            LineLayer(id: "yards-hedge", source: Self.source)
                .slot(.bottom)
                .minZoom(15.5)
                .filter(Self.kind("garden"))
                .lineColor(StyleColor(hedge))
                .lineJoin(.round)
                .lineWidth(Exp(.interpolate) {
                    Exp(.exponential) { 2 }
                    Exp(.zoom)
                    15.5
                    0.6
                    18
                    3
                    20
                    10
                })
                .lineOpacity(0.85)

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
