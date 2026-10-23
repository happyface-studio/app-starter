import SwiftUI

/// One look for the whole map. `landmark` is a separate, slightly warmer tint because Standard's
/// landmark models are lit darker than façades and can't read `colorBuildings` (see `Basemap`).
struct CityPalette: Identifiable, Hashable {
    struct Glass: Hashable {
        var hue: ClosedRange<Double>
        var saturation: ClosedRange<Double>
        var lightness: ClosedRange<Double>
    }

    var id: String
    var title: String
    var buildings: UInt32
    var landmark: UInt32
    var glass: Glass
    var land: UInt32
    /// Shops, offices, schools, hospitals, industry — kept close to `land` so blocks don't patchwork.
    var landuse: UInt32
    /// Street surface, a touch lighter than `land` so streets read as paved bands.
    var roads: UInt32
    var trunks: UInt32
    /// Road edges and tram rails.
    var curb: UInt32
    /// Plazas and footpaths.
    var paving: UInt32
    var water: UInt32
    var green: UInt32
    /// Roof colour for façade buildings and landmarks; `nil` keeps Standard's wall-derived roofs.
    var roof: UInt32? = nil
    /// Landmark models render roofs lighter and greyer than façade buildings, so they need their own input.
    var landmarkRoof: UInt32? = nil

    /// Matched to the London toy-map reference: sand walls, slate roofs, rose roads, olive parks.
    static let mayfair = CityPalette(
        id: "mayfair", title: "Mayfair",
        buildings: 0xEAC79A, landmark: 0xE4C08E,
        glass: Glass(hue: 226...234, saturation: 22...32, lightness: 36...46),
        land: 0xF2EFE7, landuse: 0xEEEBE3, roads: 0xC8988C, trunks: 0xBF8E83,
        curb: 0xE2D8CC, paving: 0xEDE1CD, water: 0x5A9AC2, green: 0xABBD5A,
        roof: 0x5F688E, landmarkRoof: 0x2C3466)

    static let linen = CityPalette(
        id: "linen", title: "Linen",
        buildings: 0xF4EBDC, landmark: 0xF9EBD2,
        glass: Glass(hue: 206...218, saturation: 38...50, lightness: 66...74),
        land: 0xF0ECE3, landuse: 0xEDE7DC, roads: 0xFCFAF6, trunks: 0xF4E6CC,
        curb: 0xE2DACC, paving: 0xE9E3D8, water: 0x5CACE2, green: 0x94CA86)

    static let cream = CityPalette(
        id: "cream", title: "Cream",
        buildings: 0xF7E9CF, landmark: 0xFCE5C0,
        glass: Glass(hue: 202...214, saturation: 42...55, lightness: 72...79),
        land: 0xF2EADF, landuse: 0xEEE4D6, roads: 0xFBF6EE, trunks: 0xF0D9C9,
        curb: 0xE6D8C2, paving: 0xEDE3D3, water: 0x62B4EC, green: 0x8CCB5E)

    static let sorbet = CityPalette(
        id: "sorbet", title: "Sorbet",
        buildings: 0xF9DCCB, landmark: 0xFCC6AE,
        glass: Glass(hue: 166...180, saturation: 34...44, lightness: 70...78),
        land: 0xF7EDE6, landuse: 0xF3E6DE, roads: 0xFDF6F2, trunks: 0xF4D2D2,
        curb: 0xEBCFC8, paving: 0xF1E2DA, water: 0x74C6E6, green: 0x9ED37F)

    static let butter = CityPalette(
        id: "butter", title: "Butter",
        buildings: 0xF8E4A8, landmark: 0xFAD47A,
        glass: Glass(hue: 196...208, saturation: 50...60, lightness: 70...78),
        land: 0xF4EBD3, landuse: 0xF0E6CC, roads: 0xFDF8EA, trunks: 0xF2DDB4,
        curb: 0xE8D7AE, paving: 0xEFE5CC, water: 0x4FAEE6, green: 0x7EC25B)

    static let seaside = CityPalette(
        id: "seaside", title: "Seaside",
        buildings: 0xF2EEE8, landmark: 0xF7F0E4,
        glass: Glass(hue: 212...224, saturation: 35...45, lightness: 62...70),
        land: 0xEDF0EA, landuse: 0xE7EBE5, roads: 0xFAFBFC, trunks: 0xE3E8EF,
        curb: 0xD9DEE5, paving: 0xE4E8E6, water: 0x56A3DA, green: 0x9CC98B)

    static let all: [CityPalette] = [.mayfair, .linen, .cream, .sorbet, .butter, .seaside]

    static func named(_ id: String?) -> CityPalette? { all.first { $0.id == id } }

    /// The same style under snow: ground, parks, pavements and roofs blend towards snow white,
    /// roads to a pale slush, water a little icier. `cover` is 0...1.
    func snowy(_ cover: Double) -> CityPalette {
        let c = max(0, min(1, cover))
        func mix(_ hex: UInt32, _ target: UInt32, _ t: Double) -> UInt32 {
            func ch(_ v: UInt32, _ s: UInt32) -> UInt32 { (v >> s) & 0xFF }
            func m(_ s: UInt32) -> UInt32 {
                UInt32((Double(ch(hex, s)) * (1 - t) + Double(ch(target, s)) * t).rounded()) << s
            }
            return m(16) | m(8) | m(0)
        }
        let snow: UInt32 = 0xF4F6FA, slush: UInt32 = 0xD9DADF
        var p = self
        p.id = "\(id)-snow\(Int(c * 10))"
        p.land = mix(land, snow, 0.85 * c)
        p.landuse = mix(landuse, snow, 0.85 * c)
        p.green = mix(green, snow, 0.8 * c)
        p.paving = mix(paving, snow, 0.8 * c)
        p.curb = mix(curb, snow, 0.7 * c)
        p.roads = mix(roads, slush, 0.7 * c)
        p.trunks = mix(trunks, slush, 0.6 * c)
        p.water = mix(water, 0x8FB4CC, 0.35 * c)
        p.roof = roof.map { mix($0, snow, 0.75 * c) } ?? mix(buildings, snow, 0.75 * c)
        p.landmarkRoof = landmarkRoof.map { mix($0, 0xC8CEDC, 0.8 * c) }
        return p
    }

    var swatch: Color { Color(UIColor(hex: buildings)) }
}

extension UInt32 {
    var hexString: String { String(format: "#%06X", self) }
}
