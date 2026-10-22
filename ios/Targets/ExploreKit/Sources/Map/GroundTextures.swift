import MapboxMaps
import UIKit

/// Lawn texture on parks and grass, and a water surface with a soft light rim along the shore.
/// Textures are alpha-only (`ios/tools/make_street_textures.py`), so they sit on any palette.
/// Drawn in the `bottom` slot: above Standard's land and water fills, below roads.
struct GroundTextures: MapStyleContent {
    var palette: CityPalette

    private static let source = "ground-textures"
    private static let lawnClasses = ["park", "grass", "pitch", "cemetery", "golf_course"]

    private static func image(_ name: String) -> UIImage? {
        UIImage(named: name, in: exploreBundle, with: nil)
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

    private static func classIn(_ classes: [String]) -> Exp {
        Exp(.match) {
            Exp(.get) { "class" }
            classes
            true
            false
        }
    }

    /// Shore rim width in pixels; it is offset inwards by half so it sits on the water side.
    private static func rim(_ factor: Double) -> Exp {
        Exp(.interpolate) {
            Exp(.exponential) { 1.6 }
            Exp(.zoom)
            13
            1.5 * factor
            16
            5 * factor
            19
            22 * factor
        }
    }

    private var shore: UIColor {
        UIColor(hex: palette.water).blended(with: .white, amount: 0.42)
    }

    var body: some MapStyleContent {
        if let grass = Self.image("tex_grass"), let water = Self.image("tex_water") {
            StyleImage(id: "tex-grass", image: grass)
            StyleImage(id: "tex-water", image: water)

            VectorSource(id: Self.source)
                .url("mapbox://mapbox.mapbox-streets-v8")

            FillLayer(id: "tex-lawn", source: Self.source)
                .sourceLayer("landuse")
                .slot(.bottom)
                .minZoom(13.5)
                .filter(Self.classIn(Self.lawnClasses))
                .fillPattern("tex-grass")
                .fillOpacity(Self.fadeIn)

            FillLayer(id: "tex-landcover-grass", source: Self.source)
                .sourceLayer("landcover")
                .slot(.bottom)
                .minZoom(13.5)
                .filter(Self.classIn(["grass"]))
                .fillPattern("tex-grass")
                .fillOpacity(Self.fadeIn)

            FillLayer(id: "tex-water", source: Self.source)
                .sourceLayer("water")
                .slot(.bottom)
                .minZoom(12.5)
                .fillPattern("tex-water")
                .fillOpacity(Self.fadeIn)

            // Two strokes make a soft gradient: a wide faint band and a narrow brighter edge.
            LineLayer(id: "tex-shore-band", source: Self.source)
                .sourceLayer("water")
                .slot(.bottom)
                .minZoom(12.5)
                .lineColor(StyleColor(shore))
                .lineWidth(Self.rim(3))
                .lineOffset(Self.rim(1.5))
                .lineBlur(Self.rim(2))
                .lineOpacity(0.6)
                .lineJoin(.round)

            LineLayer(id: "tex-shore-edge", source: Self.source)
                .sourceLayer("water")
                .slot(.bottom)
                .minZoom(12.5)
                .lineColor(StyleColor(shore))
                .lineWidth(Self.rim(0.9))
                .lineOffset(Self.rim(0.45))
                .lineBlur(Self.rim(0.35))
                .lineOpacity(0.95)
                .lineJoin(.round)
        }
    }
}

extension UIColor {
    func blended(with other: UIColor, amount t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: 1)
    }
}
