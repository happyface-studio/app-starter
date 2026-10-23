import MapboxMaps
import UIKit

/// Window bays and mansard tiles for the buildings Standard draws without façades. Each building
/// picks one of several wall tones and window styles (and one of two slate tones for its roof), so
/// a street reads as a row of different houses rather than one repeated block.
struct FacadeTile: MapStyleContent {
    var palette: CityPalette

    /// Wall tones × window styles; keep in step with the image list in `body`.
    static let tones = 5, styles = 2
    static var facadeCount: Int { tones * styles }
    static let roofTones = 2

    static func facadeID(_ p: CityPalette, _ i: Int) -> String { "facade-\(p.id)-\(i)" }
    static func mansardID(_ p: CityPalette, _ i: Int) -> String { "mansard-\(p.id)-\(i)" }

    private func facade(_ i: Int) -> StyleImage {
        StyleImage(id: Self.facadeID(palette, i), image: Self.render(palette, variant: i))
    }

    private func mansard(_ i: Int) -> StyleImage {
        StyleImage(id: Self.mansardID(palette, i), image: Self.mansard(palette, tone: i))
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
        mansard(0)
        mansard(1)
    }

    // MARK: Colours

    /// Sand (the palette's own), pale cream, warm ochre, light stone and a soft London brick.
    static func wall(_ p: CityPalette, tone: Int) -> UIColor {
        let base = UIColor(hex: p.buildings)
        switch tone % tones {
        case 1: return base.blended(with: UIColor(hex: 0xF8F0E0), amount: 0.7)
        case 2: return base.blended(with: UIColor(hex: 0xD99E5E), amount: 0.55)
        case 3: return base.blended(with: UIColor(hex: 0xE2DCD2), amount: 0.8)
        case 4: return base.blended(with: UIColor(hex: 0xB5735A), amount: 0.68)
        default: return base
        }
    }

    static func roof(_ p: CityPalette, tone: Int) -> UIColor {
        let slate = UIColor(hex: p.roof ?? p.buildings)
        return tone % roofTones == 0 ? slate : slate.blended(with: UIColor(hex: 0x4A4E5C), amount: 0.35)
    }

    // MARK: Tiles

    /// Slate with one cream dormer every two bays.
    static func mansard(_ p: CityPalette, tone: Int) -> UIImage {
        // Patterns tile in screen points and want power-of-two pixel sizes (32 × 16 px at @3x).
        let size = CGSize(width: 32.0 / 3, height: 16.0 / 3)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            roof(p, tone: tone).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let dormer = CGRect(x: 4.0, y: 1.67, width: 2.33, height: 2.67)
            UIColor(hex: p.buildings).blended(with: .white, amount: 0.25).setFill()
            let pediment = UIBezierPath()
            pediment.move(to: CGPoint(x: dormer.minX - 0.34, y: dormer.minY + 0.2))
            pediment.addLine(to: CGPoint(x: dormer.midX, y: dormer.minY - 0.8))
            pediment.addLine(to: CGPoint(x: dormer.maxX + 0.34, y: dormer.minY + 0.2))
            pediment.close()
            pediment.fill()
            ctx.fill(dormer)
            glass(p).setFill()
            ctx.fill(CGRect(x: dormer.minX + 0.5, y: dormer.minY + 0.5, width: dormer.width - 1.0, height: dormer.height - 0.84))
            UIColor(white: 0, alpha: 0.2).setFill()
            ctx.fill(CGRect(x: dormer.minX, y: dormer.maxY, width: dormer.width, height: 0.34))
        }
    }

    /// One window bay (16 px at @3x). Style 0: a framed sash window. Style 1: a taller window under
    /// a light string course, which gives the façade storey bands.
    static func render(_ p: CityPalette, variant: Int) -> UIImage {
        let size = CGSize(width: 16.0 / 3, height: 16.0 / 3)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let tone = variant % tones, style = (variant / tones) % styles
        let wallColor = wall(p, tone: tone)
        let trim = tone == 4 ? UIColor(white: 0.96, alpha: 0.85) : UIColor(white: 1, alpha: 0.45)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            wallColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            if style == 0 {
                let frame = CGRect(x: 1.5, y: 1.0, width: 2.33, height: 3.0)
                trim.setFill()
                ctx.fill(frame.insetBy(dx: -0.35, dy: -0.35))
                glass(p).setFill()
                ctx.fill(frame)
                UIColor(white: 1, alpha: 0.35).setFill()
                ctx.fill(CGRect(x: frame.minX, y: frame.midY - 0.17, width: frame.width, height: 0.34))
                UIColor(white: 0, alpha: 0.10).setFill()
                ctx.fill(CGRect(x: frame.minX - 0.35, y: frame.maxY + 0.35, width: frame.width + 0.7, height: 0.35))
            } else {
                UIColor(white: 1, alpha: 0.28).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: 0.5))          // string course
                UIColor(white: 0, alpha: 0.12).setFill()
                ctx.fill(CGRect(x: 0, y: 0.5, width: size.width, height: 0.25))       // its shadow
                let frame = CGRect(x: 1.83, y: 1.33, width: 1.67, height: 3.33)
                trim.setFill()
                ctx.fill(frame.insetBy(dx: -0.34, dy: -0.34))
                glass(p).setFill()
                ctx.fill(frame)
                UIColor(white: 1, alpha: 0.3).setFill()
                ctx.fill(CGRect(x: frame.midX - 0.17, y: frame.minY, width: 0.34, height: frame.height))
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
