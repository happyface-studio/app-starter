import MapboxMaps
import UIKit

/// Buildings Standard draws without façades, redrawn with varied wall tones and window patterns
/// (`FacadeTile`), a slate mansard storey on most houses, and a thin slate cap as the roof. Mapbox hides these footprints wherever
/// a façade building or landmark covers them, as it did for Standard's own plain layer.
struct PlainBuildings: MapStyleContent {
    var palette: CityPalette

    private static let source = "plain-buildings"

    private static let extruded = Exp(.all) {
        Exp(.eq) { Exp(.get) { "extrude" }; "true" }
        Exp(.eq) { Exp(.get) { "underground" }; "false" }
    }

    private static let height = Exp(.number) { Exp(.get) { "height" } }

    /// A stable per-building number 0..<n, so neighbours in a terrace differ but each building
    /// keeps its look. Uses `building_id`, which all stacked parts of one building share, so a
    /// building made of parts gets one look instead of a patchwork.
    private static func pick(_ n: Int, idWeight: Double) -> Exp {
        Exp(.mod) {
            Exp(.product) {
                Exp(.coalesce) { Exp(.get) { "building_id" }; Exp(.id); 0 }
                idWeight
            }
            Double(n)
        }
    }

    private static var isPart: Exp { Exp(.eq) { Exp(.get) { "type" }; "building:part" } }

    /// The slate cap is the top 0.4 m *inside* each building, so it never pokes into a part
    /// stacked on top (that overlap flickered into a checkered roof).
    static let capDepth: Double = {
        let v = UserDefaults.standard.double(forKey: "capDepth")
        return v > 0 ? v : 0.4
    }()

    /// Hospitals, schools, offices and the like are often split into many footprints; giving each
    /// part its own colour made a patchwork, so they all stay in the palette's sand (tone 0).
    private static let institutional = [
        "hospital", "school", "university", "college", "kindergarten", "commercial", "retail", "office",
        "industrial", "warehouse", "public", "civic", "government", "church", "cathedral", "train_station",
        "transportation", "parking", "garage", "garages", "hotel", "supermarket", "sports_hall", "stadium",
    ]

    private static var facadeVariant: Exp {
        Exp(.switchCase) {
            Exp(.inExpression) { Exp(.get) { "type" }; Exp(.literal) { institutional } }
            Exp(.product) { pick(FacadeTile.styles, idWeight: 7); Double(FacadeTile.tones) }
            pick(FacadeTile.facadeCount, idWeight: 1)
        }
    }
    private static var roofTone: Exp { pick(FacadeTile.roofTones, idWeight: 3) }

    /// Houses and Gründerzeit blocks (10–32 m): about seven in ten get a slate mansard storey with
    /// dormers as their top floor, the rest keep a flat roof.
    static let mansardDepth = 3.2
    private static var hasMansard: Exp {
        Exp(.all) {
            Exp(.gte) { height; 10 }
            Exp(.lte) { height; 32 }
            Exp(.not) { isPart }
            Exp(.gte) { pick(10, idWeight: 13); 3 }
        }
    }

    private static var wallTop: Exp {
        Exp(.switchCase) {
            hasMansard
            Exp(.subtract) { height; mansardDepth }
            capBase
        }
    }

    private static var capBase: Exp {
        Exp(.max) { base; Exp(.subtract) { height; capDepth } }
    }

    private static var base: Exp {
        Exp(.max) { 0; Exp(.coalesce) { Exp(.get) { "min_height" }; 0 } }
    }

    private static var fadeIn: Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            15
            0
            15.3
            1
        }
    }

    var body: some MapStyleContent {
        VectorSource(id: Self.source)
            .url("mapbox://mapbox.mapbox-streets-v8")

        FillExtrusionLayer(id: "plain-buildings-mansard", source: Self.source)
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(15)
            .filter(Exp(.all) { Self.extruded; Self.hasMansard })
            .fillExtrusionPattern(Exp(.concat) {
                "mansard-\(palette.id)-"
                Exp(.toString) { Self.roofTone }
            })
            .fillExtrusionBase(Self.wallTop)
            .fillExtrusionHeight(Self.capBase)
            .fillExtrusionOpacity(Self.fadeIn)
            .fillExtrusionVerticalGradient(false)
            .fillExtrusionCastShadows(true)

        FillExtrusionLayer(id: "plain-buildings-roof", source: Self.source)
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(15)
            .filter(Self.extruded)
            .fillExtrusionColor(UserDefaults.standard.bool(forKey: "plainCap")
                ? Exp(.toColor) { FacadeTile.roof(palette, tone: 0).cssHex }
                : Exp(.match) {
                    Self.roofTone
                    1
                    FacadeTile.roof(palette, tone: 1).cssHex
                    FacadeTile.roof(palette, tone: 0).cssHex
                })
            .fillExtrusionBase(Self.capBase)
            .fillExtrusionHeight(Self.height)
            .fillExtrusionOpacity(Self.fadeIn)
            .fillExtrusionVerticalGradient(false)
            .fillExtrusionCastShadows(false)

        FillExtrusionLayer(id: "plain-buildings", source: Self.source)
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(15)
            .filter(Self.extruded)
            .fillExtrusionPattern(UserDefaults.standard.bool(forKey: "plainFacade")
                ? Exp(.toString) { "facade-\(palette.id)-0" }
                : Exp(.concat) {
                    "facade-\(palette.id)-"
                    Exp(.toString) { Self.facadeVariant }
                })
            .fillExtrusionHeight(Self.wallTop)
            .fillExtrusionBase(Self.base)
            .fillExtrusionOpacity(Self.fadeIn)
            .fillExtrusionVerticalGradient(false)
            .fillExtrusionAmbientOcclusionIntensity(0.3)
            .fillExtrusionCastShadows(true)
    }
}

extension UIColor {
    /// "#RRGGBB" — a colour literal style expressions accept wherever a colour is expected.
    var cssHex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> Int { Int((max(0, min(1, v)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
}
