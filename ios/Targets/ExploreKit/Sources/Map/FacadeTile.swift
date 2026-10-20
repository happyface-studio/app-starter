import MapboxMaps
import UIKit

/// One window bay in the palette's wall and glass colours, tiled over the walls of buildings
/// that Standard draws without façades.
struct FacadeTile: MapStyleContent {
    var palette: CityPalette

    static func imageID(_ p: CityPalette) -> String { "facade-\(p.id)" }

    var body: some MapStyleContent {
        StyleImage(id: Self.imageID(palette), image: Self.render(palette))
    }

    static func render(_ p: CityPalette) -> UIImage {
        let size = CGSize(width: 16, height: 16)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let wall = UIColor(hex: p.buildings)
            wall.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let frame = CGRect(x: 4.5, y: 3.5, width: 7, height: 9)
            UIColor(white: 1, alpha: 0.45).setFill()
            ctx.fill(frame.insetBy(dx: -0.8, dy: -0.8))
            glass(p).setFill()
            ctx.fill(frame)
            UIColor(white: 1, alpha: 0.35).setFill()
            ctx.fill(CGRect(x: frame.minX, y: frame.midY - 0.3, width: frame.width, height: 0.6))
            ctx.fill(CGRect(x: frame.midX - 0.3, y: frame.minY, width: 0.6, height: frame.height))
            UIColor(white: 0, alpha: 0.10).setFill()
            ctx.fill(CGRect(x: frame.minX - 0.8, y: frame.maxY + 0.8, width: frame.width + 1.6, height: 0.8))
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
