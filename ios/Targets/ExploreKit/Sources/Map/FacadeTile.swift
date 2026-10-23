import MapboxMaps
import UIKit

/// Window bays for the buildings Standard draws without façades. Each building
/// picks one of several wall tones and window styles (and one of two slate tones for its roof), so
/// a street reads as a row of different houses rather than one repeated block.
struct FacadeTile: MapStyleContent {
    var palette: CityPalette
    /// After dark the bays are drawn with a mix of lit and dark windows on a darker wall.
    var night = false

    /// Wall tones × window styles; keep in step with the image list in `body`.
    static let tones = 8, styles = 3
    static var facadeCount: Int { tones * styles }
    static let roofTones = 2
    /// Ground floor: 0 shopfront, 1 entrance door with small windows.
    static let groundStyles = 2

    static func facadeID(_ p: CityPalette, _ i: Int) -> String { "facade-\(p.id)-\(i)" }
    static func osmFacadeID(_ p: CityPalette, _ hex: String) -> String { "facade-\(p.id)-osm-\(hex.dropFirst())" }
    static func groundID(_ p: CityPalette, tone: Int, style: Int) -> String { "ground-\(p.id)-\(tone)-\(style)" }
    static func osmGroundID(_ p: CityPalette, _ hex: String, style: Int) -> String { "ground-\(p.id)-osm-\(hex.dropFirst())-\(style)" }

    /// Façades in real OSM colours; their number depends on the data, so they're added at runtime.
    @MainActor
    static func addOSMImages(_ map: MapboxMap, palette: CityPalette, night: Bool) {
        for hex in BuildingLook.wallColours {
            let wall = UIColor(hexString: hex)
            try? map.addImage(render(palette, variant: 0, wall: wall, night: night), id: osmFacadeID(palette, hex))
            for st in 0..<groundStyles {
                try? map.addImage(ground(palette, wall: wall, style: st, night: night), id: osmGroundID(palette, hex, style: st))
            }
        }
    }

    private func facade(_ i: Int) -> StyleImage {
        StyleImage(id: Self.facadeID(palette, i), image: Self.render(palette, variant: i, night: night))
    }

    private func ground(_ tone: Int, _ style: Int) -> StyleImage {
        StyleImage(id: Self.groundID(palette, tone: tone, style: style),
                   image: Self.ground(palette, wall: Self.wall(palette, tone: tone), style: style, night: night))
    }

    var body: some MapStyleContent {
        facade(0)
        facade(1)
        facade(2)
        facade(3)
        facade(4)
        facade(5)
        facade(6)
        facade(7)
        facade(8)
        facade(9)
        facade(10)
        facade(11)
        facade(12)
        facade(13)
        facade(14)
        facade(15)
        facade(16)
        facade(17)
        facade(18)
        facade(19)
        facade(20)
        facade(21)
        facade(22)
        facade(23)
        ground(0, 0)
        ground(0, 1)
        ground(1, 0)
        ground(1, 1)
        ground(2, 0)
        ground(2, 1)
        ground(3, 0)
        ground(3, 1)
        ground(4, 0)
        ground(4, 1)
        ground(5, 0)
        ground(5, 1)
        ground(6, 0)
        ground(6, 1)
        ground(7, 0)
        ground(7, 1)
    }

    // MARK: Colours

    /// Sand (the palette's own), pale cream, warm ochre, light stone, a soft London brick, and
    /// off-white, light grey and warm grey plaster, which most Frankfurt façades actually are.
    static func wall(_ p: CityPalette, tone: Int) -> UIColor {
        let base = UIColor(hex: p.buildings)
        switch tone % tones {
        case 1: return base.blended(with: UIColor(hex: 0xF8F0E0), amount: 0.7)
        case 2: return base.blended(with: UIColor(hex: 0xD99E5E), amount: 0.55)
        case 3: return base.blended(with: UIColor(hex: 0xE2DCD2), amount: 0.8)
        case 4: return base.blended(with: UIColor(hex: 0xB5735A), amount: 0.68)
        case 5: return base.blended(with: UIColor(hex: 0xF6F2EA), amount: 0.88)
        case 6: return base.blended(with: UIColor(hex: 0xDCDBD7), amount: 0.85)
        case 7: return base.blended(with: UIColor(hex: 0xCFC8BD), amount: 0.8)
        default: return base
        }
    }

    /// The pitched-roof colour for a building, picked from its id (same rule on device and in
    /// style expressions, so roofs and the caps under them match).
    static func pitchedRoof(_ p: CityPalette, id: Int) -> UIColor {
        UIColor(hex: p.roofs[((id % 1_000_003) * 7) % p.roofs.count])
    }

    static func pitchedRoofExp(_ p: CityPalette) -> Any {
        ["to-color", ["at", ["%", ["*", ["%", ["to-number", ["id"], 0], 1_000_003], 7], Double(p.roofs.count)],
                      ["literal", p.roofs.map { UIColor(hex: $0).cssHex }]]] as [Any]
    }

    static func roof(_ p: CityPalette, tone: Int) -> UIColor {
        let slate = UIColor(hex: p.roof ?? p.buildings)
        return tone % roofTones == 0 ? slate : slate.blended(with: UIColor(hex: 0x4A4E5C), amount: 0.35)
    }

    // MARK: Tiles

    private static let lit = UIColor(hex: 0xFFD79A), unlit = UIColor(hex: 0x2B3148)

    /// Night walls: darker so lit windows stand out (the layer glows a little after dark).
    private static func nightWall(_ c: UIColor) -> UIColor { c.blended(with: UIColor(hex: 0x1C2033), amount: 0.62) }

    /// Window bays, 32 px per bay at @3x (patterns tile in screen space and want power-of-two
    /// sizes). Bays are mostly wall so façades don't turn into a dense window grid.
    /// Style 0: one sash window. Style 1: a pair of narrow windows. Style 2: a tall window under a
    /// light string course, which gives the façade storey bands.
    /// At night the tile is 2 × 2 bays with a different mix of lit windows, so whole façades don't
    /// switch on at once.
    static func render(_ p: CityPalette, variant: Int, wall override: UIColor? = nil, night: Bool = false) -> UIImage {
        let bay = 32.0 / 3
        let n = night ? 2 : 1
        let size = CGSize(width: bay * Double(n), height: bay * Double(n))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let tone = variant % tones, style = (variant / tones) % styles
        let day = override ?? wall(p, tone: tone)
        let wallColor = night ? nightWall(day) : day
        let trim = tone == 4 ? UIColor(white: 0.96, alpha: 0.8) : UIColor(white: 1, alpha: night ? 0.15 : 0.4)
        var seed = UInt64(truncatingIfNeeded: variant &* 2_654_435_761 &+ 97)
        func coin() -> Bool { seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407; return (seed >> 33) % 100 < 45 }
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            wallColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            for by in 0..<n {
                for bx in 0..<n {
                    let o = CGPoint(x: Double(bx) * bay, y: Double(by) * bay)
                    let pane = night ? (coin() ? lit : unlit) : glass(p)
                    func window(_ r0: CGRect, bar: Bool) {
                        let r = r0.offsetBy(dx: o.x, dy: o.y)
                        trim.setFill()
                        ctx.fill(r.insetBy(dx: -0.34, dy: -0.34))
                        pane.setFill()
                        ctx.fill(r)
                        if bar {
                            UIColor(white: 1, alpha: night ? 0.1 : 0.3).setFill()
                            ctx.fill(CGRect(x: r.minX, y: r.midY - 0.17, width: r.width, height: 0.34))
                        }
                        UIColor(white: 0, alpha: 0.1).setFill()
                        ctx.fill(CGRect(x: r.minX - 0.34, y: r.maxY + 0.34, width: r.width + 0.68, height: 0.34))
                    }
                    switch style {
                    case 1:
                        window(CGRect(x: 3.0, y: 3.0, width: 1.67, height: 4.33), bar: false)
                        window(CGRect(x: 6.0, y: 3.0, width: 1.67, height: 4.33), bar: false)
                    case 2:
                        UIColor(white: 1, alpha: night ? 0.08 : 0.22).setFill()
                        ctx.fill(CGRect(x: o.x, y: o.y + 1.0, width: bay, height: 0.67))
                        window(CGRect(x: 4.0, y: 3.0, width: 2.67, height: 5.0), bar: true)
                    default:
                        window(CGRect(x: 3.67, y: 3.0, width: 3.33, height: 4.33), bar: true)
                    }
                }
            }
        }
    }

    /// The ground floor bay: a darker plinth with a shopfront (wide glass, light frame) or an
    /// entrance door between two small windows. Shop glass is warm-lit at night.
    static func ground(_ p: CityPalette, wall: UIColor, style: Int, night: Bool) -> UIImage {
        let size = CGSize(width: 32.0 / 3, height: 32.0 / 3)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let base = wall.blended(with: UIColor(hex: 0x6B6157), amount: 0.18)
        let w = night ? nightWall(base) : base
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            w.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0, alpha: 0.12).setFill()
            ctx.fill(CGRect(x: 0, y: size.height - 1.0, width: size.width, height: 1.0))      // plinth
            if style == 0 {
                UIColor(white: 0.97, alpha: night ? 0.3 : 0.85).setFill()
                ctx.fill(CGRect(x: 0.67, y: 2.0, width: size.width - 1.33, height: 7.0))
                (night ? lit : glass(p).blended(with: .white, amount: 0.18)).setFill()
                ctx.fill(CGRect(x: 1.0, y: 2.33, width: size.width - 2.0, height: 6.33))
            } else {
                UIColor(hex: 0x5A4A3C).setFill()
                ctx.fill(CGRect(x: 4.0, y: 2.67, width: 2.67, height: 6.67))                 // door
                (night ? unlit : glass(p)).setFill()
                ctx.fill(CGRect(x: 1.0, y: 3.67, width: 1.67, height: 3.0))
                ctx.fill(CGRect(x: 8.0, y: 3.67, width: 1.67, height: 3.0))
            }
        }
    }

    /// Middle of the palette's glass range, HSL to RGB.
    private static func glass(_ p: CityPalette) -> UIColor {
        let h = (p.glass.hue.lowerBound + p.glass.hue.upperBound) / 2 / 360
        let s = (p.glass.saturation.lowerBound + p.glass.saturation.upperBound) / 2 / 100
        let l = (p.glass.lightness.lowerBound + p.glass.lightness.upperBound) / 2 / 100
        let c = (1 - abs(2 * l - 1)) * s
        func f(_ n: Double) -> Double {
            let k = (n + h * 12).truncatingRemainder(dividingBy: 12)
            return l - c / 2 * max(-1, min(k - 3, 9 - k, 1))
        }
        return UIColor(red: f(0), green: f(8), blue: f(4), alpha: 1)
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let v = UInt32(hexString.dropFirst(), radix: 16) ?? 0xFFFFFF
        self.init(hex: v)
    }
}
