import MapboxMaps
import UIKit

/// One window bay in the palette's wall and glass colours, tiled over the walls of buildings
/// that Standard draws without façades.
struct FacadeTile: MapStyleContent {
    var palette: CityPalette

    static func imageID(_ p: CityPalette) -> String { "facade-\(p.id)" }

    static func mansardID(_ p: CityPalette) -> String { "mansard-\(p.id)" }

    var body: some MapStyleContent {
        StyleImage(id: Self.imageID(palette), image: Self.render(palette))
        StyleImage(id: Self.mansardID(palette), image: Self.mansard(palette))
    }

    /// Slate with one cream dormer per bay, for the mansard storey of plain buildings.
    static func mansard(_ p: CityPalette) -> UIImage {
        // Two window bays wide with one dormer, so the storey reads as slate.
        let size = CGSize(width: 32.0 / 3, height: 16.0 / 3)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor(hex: p.roof ?? p.buildings).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 1, alpha: 0.06).setFill()
            for y in stride(from: 0.0, to: size.height, by: 1.0) {
                ctx.fill(CGRect(x: 0, y: y, width: size.width, height: 0.33))
            }
            let dormer = CGRect(x: 4.0, y: 1.67, width: 2.33, height: 2.67)
            UIColor(hex: p.buildings).setFill()
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

    static func render(_ p: CityPalette) -> UIImage {
        // Patterns tile in screen points at the current zoom, so the bay is small. 16 px at @3x:
        // seamless tiling wants power-of-two pixel sizes.
        let size = CGSize(width: 16.0 / 3, height: 16.0 / 3)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let wall = UIColor(hex: p.buildings)
            wall.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let frame = CGRect(x: 1.5, y: 1.0, width: 2.33, height: 3.0)
            UIColor(white: 1, alpha: 0.45).setFill()
            ctx.fill(frame.insetBy(dx: -0.35, dy: -0.35))
            glass(p).setFill()
            ctx.fill(frame)
            UIColor(white: 1, alpha: 0.35).setFill()
            ctx.fill(CGRect(x: frame.minX, y: frame.midY - 0.17, width: frame.width, height: 0.34))
            
            UIColor(white: 0, alpha: 0.10).setFill()
            ctx.fill(CGRect(x: frame.minX - 0.35, y: frame.maxY + 0.35, width: frame.width + 0.7, height: 0.35))
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
