@_spi(Experimental) import MapboxMaps
import UIKit

/// The open ground between streets and houses: a soft sandy texture over all bare land, soft
/// rounded lawns in back gardens and clumps of garden trees (data baked by `ios/tools/bake_yards.py`).
/// Hard-edged lawn, hedge and paving fills were tried first and dropped: they read as flat blobs.
///
/// `-ground gravel` shows only the texture and trees (no lawns), for comparing looks.
struct Yards: MapStyleContent {
    var palette: CityPalette

    static let showsLawns = UserDefaults.standard.string(forKey: "ground") != "gravel"

    private var lawn: UIColor { UIColor(hex: palette.land).blended(with: UIColor(hex: palette.green), amount: 0.78) }

    /// One polygon over all of Frankfurt carrying the ground texture; water and parks get solid
    /// fills above it in `GroundTextures`, so only bare land shows the grain.
    private static let groundArea: FeatureCollection = {
        let ring = [(8.50, 50.03), (8.85, 50.03), (8.85, 50.22), (8.50, 50.22), (8.50, 50.03)]
            .map { CLLocationCoordinate2D(latitude: $0.1, longitude: $0.0) }
        return FeatureCollection(features: [Feature(geometry: .polygon(Polygon([ring])))])
    }()

    private static let source = "yards"

    private static func kind(_ k: String) -> Exp {
        Exp(.eq) { Exp(.get) { "k" }; k }
    }

    private static func kinds(_ ks: [String]) -> Exp {
        Exp(.match) { Exp(.get) { "k" }; ks; true; false }
    }

    private var hedge: UIColor { UIColor(hex: palette.green).blended(with: UIColor(hex: 0x2F4A22), amount: 0.45) }

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
        if let ground = UIImage(named: "tex_ground", in: exploreBundle, with: nil) {
            StyleImage(id: "tex-ground", image: ground)
            GeoJSONSource(id: "ground-area").data(.featureCollection(Self.groundArea))
            FillLayer(id: "ground-texture", source: "ground-area")
                .slot(.bottom)
                .minZoom(13)
                .fillPattern("tex-ground")
        }

        if let url = exploreBundle.url(forResource: "frankfurt_yards", withExtension: "geojson") {
            GeoJSONSource(id: Self.source).data(.url(url))

            if Self.showsLawns {
                FillLayer(id: "yards-lawn", source: Self.source)
                    .slot(.bottom)
                    .minZoom(14)
                    .filter(Self.kinds(["lawn", "front"]))
                    .fillColor(StyleColor(lawn))
                    .fillOpacity(Exp(.interpolate) {
                        Exp(.linear)
                        Exp(.zoom)
                        14
                        0
                        15
                        0.9
                    })
                FillLayer(id: "yards-lawn-tex", source: Self.source)
                    .slot(.bottom)
                    .minZoom(15)
                    .filter(Self.kinds(["lawn", "front"]))
                    .fillPattern("tex-grass")
                    .fillOpacity(0.8)
            }

            FillExtrusionLayer(id: "yards-hedges", source: Self.source)
                .slot(.middle)
                .minZoom(16)
                .filter(Self.kind("hedge"))
                .fillExtrusionColor(StyleColor(hedge))
                .fillExtrusionHeight(1.1)
                .fillExtrusionBase(0)
                .fillExtrusionEdgeRadius(0.3)
                .fillExtrusionVerticalGradient(false)
                .fillExtrusionCastShadows(true)
                .fillExtrusionOpacity(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.zoom)
                    16
                    0
                    16.4
                    1
                })

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
