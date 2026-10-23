import MapboxMaps
import UIKit

/// Window bays for the buildings Standard draws without façades. Each building
/// picks one of several wall tones and window styles (and one of two slate tones for its roof), so
/// a street reads as a row of different houses rather than one repeated block.
struct FacadeTile: MapStyleContent {
    var palette: CityPalette

    /// Wall tones × window styles; keep in step with the image list in `body`.
    static let tones = 8, styles = 3
    static var facadeCount: Int { tones * styles }
    static let roofTones = 2

    static func facadeID(_ p: CityPalette, _ i: Int) -> String { "facade-\(p.id)-\(i)" }

    static func osmFacadeID(_ p: CityPalette, _ hex: String) -> String { "facade-\(p.id)-osm-\(hex.dropFirst())" }

    /// Façades in real OSM colours; their number depends on the data, so they're added at runtime.
    @MainActor
    static func addOSMImages(_ map: MapboxMap, palette: CityPalette) {
        for hex in BuildingLook.wallColours {
            try? map.addImage(render(palette, variant: 0, wall: UIColor(hexString: hex)), id: osmFacadeID(palette, hex))
        }
    }

    private func facade(_ i: Int) -> StyleImage {
        StyleImage(id: Self.facadeID(palette, i), image: Self.render(palette, variant: i))
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

    static func roof(_ p: CityPalette, tone: Int) -> UIColor {
        let slate = UIColor(hex: p.roof ?? p.buildings)
        return tone % roofTones == 0 ? slate : slate.blended(with: UIColor(hex: 0x4A4E5C), amount: 0.35)
    }

    // MARK: Tiles

    /// One window bay, 32 px at @3x (patterns tile in screen space and want power-of-two sizes).
    /// The bay is mostly wall so façades don't turn into a dense window grid.
    /// Style 0: one sash window. Style 1: a pair of narrow windows. Style 2: a tall window under a
    /// light string course, which gives the façade storey bands.
    static func render(_ p: CityPalette, variant: Int, wall override: UIColor? = nil) -> UIImage {
        let size = CGSize(width: 32.0 / 3, height: 32.0 / 3)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let tone = variant % tones, style = (variant / tones) % styles
        let wallColor = override ?? wall(p, tone: tone)
        let trim = tone == 4 ? UIColor(white: 0.96, alpha: 0.8) : UIColor(white: 1, alpha: 0.4)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            wallColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            func window(_ r: CGRect, bar: Bool) {
                trim.setFill()
                ctx.fill(r.insetBy(dx: -0.34, dy: -0.34))
                glass(p).setFill()
                ctx.fill(r)
                if bar {
                    UIColor(white: 1, alpha: 0.3).setFill()
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
                UIColor(white: 1, alpha: 0.22).setFill()
                ctx.fill(CGRect(x: 0, y: 1.0, width: size.width, height: 0.67))
                window(CGRect(x: 4.0, y: 3.0, width: 2.67, height: 5.0), bar: true)
            default:
                window(CGRect(x: 3.67, y: 3.0, width: 3.33, height: 4.33), bar: true)
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
