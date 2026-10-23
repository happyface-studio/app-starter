import MapboxMaps
import UIKit

/// Standard's road widths (pixels per zoom stop and class), so overlays line up with its roads.
enum RoadWidth {
    static let drivable = [
        "motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link",
        "secondary", "secondary_link", "tertiary", "tertiary_link", "street", "street_limited",
    ]

    /// Width per zoom stop for each class group; the last entry is the fallback.
    private static let table: [(zoom: Double, groups: [([String], Double)], fallback: Double)] = [
        (12, [(["motorway", "trunk"], 3.2), (["primary"], 3), (["secondary", "tertiary"], 2.2),
              (["motorway_link", "trunk_link"], 0.8), (["street", "street_limited"], 0.5),
              (["primary_link", "secondary_link", "tertiary_link"], 0.4)], 0),
        (18, [(["motorway", "trunk"], 30), (["primary"], 28), (["secondary", "tertiary"], 26),
              (["motorway_link", "trunk_link", "street", "street_limited"], 20),
              (["primary_link", "secondary_link", "tertiary_link"], 18)], 10),
        (22, [(["motorway", "trunk"], 300), (["primary"], 280), (["secondary", "tertiary"], 260),
              (["motorway_link", "trunk_link", "street", "street_limited"], 200),
              (["primary_link", "secondary_link", "tertiary_link"], 180)], 100),
    ]

    /// `f(width)` at every stop; zoom curves must stay top-level, so this rebuilds the whole curve.
    static func exp(_ f: (Double) -> Double = { $0 }) -> Exp {
        var args: [Exp.Argument] = [
            .expression(Exp(operator: .exponential, arguments: [.number(1.5)])),
            .expression(Exp(.zoom)),
        ]
        for stop in table {
            var match: [Exp.Argument] = [.expression(Exp(.get) { "class" })]
            for (classes, w) in stop.groups {
                match.append(.stringArray(classes))
                match.append(.number(f(w)))
            }
            match.append(.number(f(stop.fallback)))
            args.append(.number(stop.zoom))
            args.append(.expression(Exp(operator: .match, arguments: match)))
        }
        return Exp(operator: .interpolate, arguments: args)
    }
}

/// Raised kerbs and pavements along every street, like the toy-city reference: a pale pavement band
/// either side of the carriageway, a shaded kerb face and a bright kerb top.
///
/// These are offset lines in the `bottom` slot, so Standard's roads paint over them at junctions and
/// the kerb drops where side streets join.
struct Kerbs: MapStyleContent {
    var palette: CityPalette

    private static let source = "kerbs"
    private static let classes = ["trunk", "trunk_link", "primary", "primary_link", "secondary", "secondary_link",
                                  "tertiary", "tertiary_link", "street", "street_limited"]

    // Pavement, kerb face and kerb top widths as fractions of the carriageway width (plus a pixel floor).
    private static func pavement(_ w: Double) -> Double { 0.5 * w + 0.6 }
    private static func face(_ w: Double) -> Double { 0.055 * w + 0.5 }
    private static func top(_ w: Double) -> Double { 0.07 * w + 0.6 }

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

    private var filter: Exp {
        Exp(.all) {
            Exp(.match) {
                Exp(.get) { "class" }
                Self.classes
                true
                false
            }
            Exp(.match) {
                Exp(.get) { "structure" }
                ["none", "ford"]
                true
                false
            }
            Exp(.eq) { Exp(.geometryType); "LineString" }
        }
    }

    private var pavementColor: UIColor {
        // Pavements sit between the ground and the curb colour; deriving them from the (now dark)
        // asphalt made them muddy.
        UIColor(hex: palette.paving).blended(with: UIColor(hex: palette.curb), amount: 0.35)
    }

    private func line(_ id: String, side: Double, width: @escaping (Double) -> Double,
                      inner: @escaping (Double) -> Double, color: UIColor) -> LineLayer {
        LineLayer(id: id, source: Self.source)
            .sourceLayer("road")
            .slot(.bottom)
            .minZoom(15)
            .filter(filter)
            .lineJoin(.round)
            .lineCap(.butt)
            .lineColor(StyleColor(color))
            .lineWidth(RoadWidth.exp(width))
            .lineOffset(RoadWidth.exp { side * (0.5 * $0 + inner($0) + 0.5 * width($0)) })
            .lineOpacity(Self.fadeIn)
    }

    @MapStyleContentBuilder
    private func side(_ side: Double) -> some MapStyleContent {
        let s = side > 0 ? "r" : "l"
        let pave = pavementColor
        let faceColor = pave.blended(with: .black, amount: 0.22)
        let topColor = UIColor(hex: palette.curb).blended(with: .white, amount: 0.45)
        let pastKerb: (Double) -> Double = { Self.face($0) + Self.top($0) }
        line("kerb-pavement-\(s)", side: side, width: Self.pavement, inner: pastKerb, color: pave)
        line("kerb-pavement-tex-\(s)", side: side, width: Self.pavement, inner: pastKerb, color: pave)
            .linePattern("tex-slabs")
        line("kerb-face-\(s)", side: side, width: Self.face, inner: { _ in 0 }, color: faceColor)
        line("kerb-top-\(s)", side: side, width: Self.top, inner: Self.face, color: topColor)
    }

    var body: some MapStyleContent {
        VectorSource(id: Self.source)
            .url("mapbox://mapbox.mapbox-streets-v8")
        side(1)
        side(-1)
    }
}
