import MapboxMaps
import UIKit

/// Buildings Standard draws without façades, redrawn with varied wall tones and window patterns
/// (`FacadeTile`) and a slate cap as the roof. Mapbox hides these footprints wherever
/// a façade building or landmark covers them, as it did for Standard's own plain layer.
struct PlainBuildings: MapStyleContent {
    var palette: CityPalette
    var night = false

    private static let source = "plain-buildings"

    private static let extruded = Exp(.all) {
        Exp(.eq) { Exp(.get) { "extrude" }; "true" }
        Exp(.eq) { Exp(.get) { "underground" }; "false" }
    }

    /// Real height plus up to 1.6 m per building, so a terrace reads as separate houses.
    /// Deterministic (not `random`) so `RoofBuilder` can put roofs exactly on top.
    static func jitter(id: Int) -> Double { Double(id % 17) / 16 * 1.6 }
    private static let height = Exp.json(["+", ["number", ["get", "height"]], ["*", ["/", ["%", ["id"], 17], 16], 1.6]] as [Any])

    /// Ground floor height; buildings under 7 m keep one wall.
    static let groundFloor = 3.8
    private static var hasGround: Exp { Exp.json([">=", ["-", ["number", ["get", "height"]], ["coalesce", ["get", "min_height"], 0]], 7] as [Any]) }
    private static var upperBase: Exp {
        Exp(.switchCase) {
            hasGround
            Exp(.sum) { base; groundFloor }
            base
        }
    }

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


    /// The slate cap is the top 1.5 m *inside* each building, so it never pokes into a part stacked
    /// on top. It has to be this thick: at the zoom levels most views use, a thinner cap and the
    /// patterned wall top beneath it flicker into a checkered roof.
    static let capDepth = 1.5

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

    private static var wallTop: Exp { capBase }

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

        FillExtrusionLayer(id: "plain-buildings-roof", source: Self.source)
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(15)
            .filter(Self.extruded)
            // Slate under the pitched roofs (`RoofBuilder`), gravel grey on flat roofs.
            .fillExtrusionColor(Exp.json(BuildingLook.roofColour(fallback: [
                "case", BuildingLook.pitchedExp,
                ["match", Self.json(Self.roofTone), 1, FacadeTile.roof(palette, tone: 1).cssHex, FacadeTile.roof(palette, tone: 0).cssHex],
                UIColor(hex: palette.flatRoof).cssHex,
            ] as [Any])))
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
            // Real OSM façade colour where mapped, else one of the mixed tones.
            .fillExtrusionPattern(Exp.json(BuildingLook.wallImage({ FacadeTile.osmFacadeID(palette, $0) }, fallback: [
                "concat", "facade-\(palette.id)-", ["to-string", Self.json(Self.facadeVariant)],
            ] as [Any])))
            .fillExtrusionHeight(Self.wallTop)
            .fillExtrusionBase(Self.upperBase)
            .fillExtrusionOpacity(Self.fadeIn)
            .fillExtrusionVerticalGradient(false)
            .fillExtrusionAmbientOcclusionIntensity(0)
            .fillExtrusionEmissiveStrength(night ? 0.75 : 0)
            .fillExtrusionCastShadows(true)

        // Ground floor: shopfronts or entrance doors on a darker plinth.
        FillExtrusionLayer(id: "plain-buildings-ground", source: Self.source)
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(15)
            .filter(Exp(.all) { Self.extruded; Self.hasGround })
            .fillExtrusionPattern(Exp.json(BuildingLook.wallImage({ FacadeTile.osmGroundID(palette, $0, style: 0) }, fallback: [
                "concat", "ground-\(palette.id)-",
                ["to-string", ["%", Self.json(Self.facadeVariant), Double(FacadeTile.tones)]], "-",
                ["to-string", ["%", ["coalesce", ["id"], 0], Double(FacadeTile.groundStyles)]],
            ] as [Any])))
            .fillExtrusionBase(Self.base)
            .fillExtrusionHeight(Exp(.sum) { Self.base; Self.groundFloor })
            .fillExtrusionOpacity(Self.fadeIn)
            .fillExtrusionVerticalGradient(false)
            .fillExtrusionAmbientOcclusionIntensity(0)
            .fillExtrusionEmissiveStrength(night ? 0.75 : 0)
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

extension PlainBuildings {
    /// An `Exp` as plain JSON, to splice into hand-built expressions.
    static func json(_ e: Exp) -> Any {
        guard let data = try? JSONEncoder().encode(e) else { return NSNull() }
        return (try? JSONSerialization.jsonObject(with: data)) ?? NSNull()
    }
}

extension Exp {
    /// Decodes a JSON expression built as nested arrays.
    static func json(_ value: Any) -> Exp {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
              let e = try? JSONDecoder().decode(Exp.self, from: data) else { return Exp(.literal) { 0 } }
        return e
    }
}
