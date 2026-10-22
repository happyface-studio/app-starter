import MapboxMaps
import QuartzCore
import UIKit

/// Slowly drifts the water texture by redrawing the `tex-water` pattern shifted a fraction of a
/// pixel each frame. The tile is seamless, so the shift wraps without a seam.
@MainActor
final class WaterDrift: NSObject {
    static let shared = WaterDrift()

    /// Drift in tile pixels per second (the tile is 256 px at @2x, so 6 px/s is 3 pt/s).
    private let velocity = CGVector(dx: 6, dy: 1.5)
    private let imageID = "tex-water"

    private weak var map: MapboxMap?
    private var link: CADisplayLink?
    private var tile: CGImage?
    private var offset = CGPoint.zero
    private var last: CFTimeInterval = 0

    func start(map: MapboxMap?) {
        self.map = map
        guard link == nil else { return }
        tile = UIImage(named: "tex_water", in: exploreBundle, with: nil)?.cgImage
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 6, maximum: 10, preferred: 8)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let map, let tile else { return }
        let dt = last == 0 ? 0 : min(link.timestamp - last, 0.2)
        last = link.timestamp
        let w = CGFloat(tile.width), h = CGFloat(tile.height)
        offset.x = (offset.x + velocity.dx * dt).truncatingRemainder(dividingBy: w)
        offset.y = (offset.y + velocity.dy * dt).truncatingRemainder(dividingBy: h)
        // Re-uploading the texture while the user pans competes with rendering; hold the drift then.
        guard map.cameraState.zoom >= 12.5, !map.isGestureInProgress, let frame = shifted(tile, by: offset) else { return }
        try? map.addImage(frame, id: imageID)
    }

    private func shifted(_ tile: CGImage, by o: CGPoint) -> UIImage? {
        let w = tile.width, h = tile.height
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .low
        let fw = CGFloat(w), fh = CGFloat(h)
        for dx in [0, -fw] {
            for dy in [0, -fh] {
                ctx.draw(tile, in: CGRect(x: o.x + dx, y: o.y + dy, width: fw, height: fh))
            }
        }
        guard let out = ctx.makeImage() else { return nil }
        return UIImage(cgImage: out, scale: 2, orientation: .up)
    }
}
