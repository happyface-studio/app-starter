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
    var roads: UInt32
    var trunks: UInt32
    var water: UInt32
    var green: UInt32

    static let cream = CityPalette(
        id: "cream", title: "Cream",
        buildings: 0xF7E9CF, landmark: 0xFCE5C0,
        glass: Glass(hue: 202...214, saturation: 42...55, lightness: 72...79),
        land: 0xF2EADF, roads: 0xDDB3B5, trunks: 0xC98F92, water: 0x62B4EC, green: 0x8CCB5E)

    static let sorbet = CityPalette(
        id: "sorbet", title: "Sorbet",
        buildings: 0xF9DCCB, landmark: 0xFDD8C0,
        glass: Glass(hue: 166...180, saturation: 34...44, lightness: 70...78),
        land: 0xF7EDE6, roads: 0xF0BFC4, trunks: 0xE39AA6, water: 0x74C6E6, green: 0x9ED37F)

    static let butter = CityPalette(
        id: "butter", title: "Butter",
        buildings: 0xF8E4A8, landmark: 0xFCE29C,
        glass: Glass(hue: 196...208, saturation: 50...60, lightness: 70...78),
        land: 0xF4EBD3, roads: 0xE8C49D, trunks: 0xD9A274, water: 0x4FAEE6, green: 0x7EC25B)

    static let seaside = CityPalette(
        id: "seaside", title: "Seaside",
        buildings: 0xF2EEE8, landmark: 0xF7F0E4,
        glass: Glass(hue: 212...224, saturation: 35...45, lightness: 62...70),
        land: 0xEDF0EA, roads: 0xD6DCE6, trunks: 0xB9C4D6, water: 0x56A3DA, green: 0x9CC98B)

    static let all: [CityPalette] = [.cream, .sorbet, .butter, .seaside]

    static func named(_ id: String?) -> CityPalette? { all.first { $0.id == id } }

    var swatch: Color { Color(UIColor(hex: buildings)) }
}

extension UInt32 {
    var hexString: String { String(format: "#%06X", self) }
}
