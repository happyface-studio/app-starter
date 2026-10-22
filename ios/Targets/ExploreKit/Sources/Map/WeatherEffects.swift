@_spi(Experimental) import MapboxMaps
import QuartzCore
import UIKit

/// Mapbox's built-in screen-space rain and snow, driven by the live Frankfurt weather.
struct WeatherEffects: MapStyleContent {
    var sky: Sky

    var body: some MapStyleContent {
        if sky == .drizzle {
            Rain().density(0.35).intensity(0.4).opacity(0.35).vignette(0.2)
        } else if sky == .rain {
            Rain().density(0.6).intensity(0.7).opacity(0.45).vignette(0.3)
        } else if sky == .storm {
            Rain().density(0.9).intensity(1).opacity(0.55).vignette(0.45)
        } else if sky == .snow {
            Snow().density(0.6).intensity(0.6).opacity(0.8).vignette(0.25)
        }
    }
}

/// Soft cloud shadows: one map-anchored image (a seamless tile repeated 2x2) that drifts with the
/// live wind. The offset wraps every tile width, which is invisible because the neighbours match.
struct CloudShadows: MapStyleContent {
    var mood: MapMood
    var sky: Sky

    static let sourceID = "cloud-shadows"

    private var opacity: Double {
        guard mood == .day || mood == .dawn || mood == .dusk else { return 0 }
        return switch sky {
        case .clear: 0.16
        case .partly: 0.32
        case .cloudy, .fog: 0.22
        default: 0.14
        }
    }

    var body: some MapStyleContent {
        if let url = exploreBundle.url(forResource: "clouds", withExtension: "png") {
            ImageSource(id: Self.sourceID)
                .url(url.absoluteString)
                .coordinates(CloudDrift.corners(offset: .zero))


            RasterLayer(id: "cloud-shadows", source: Self.sourceID)
                .slot(.middle)
                .rasterOpacity(opacity)
                .rasterOpacityTransition(StyleTransition(duration: 3, delay: 0))
                .rasterFadeDuration(0)
        }
    }
}

@MainActor
final class CloudDrift: NSObject {
    static let shared = CloudDrift()

    /// Side of one cloud tile in metres; the image spans 2x2 tiles around the city.
    nonisolated static let tile = 6000.0
    nonisolated private static let center = (lat: 50.112, lon: 8.68)

    private weak var map: MapboxMap?
    private var link: CADisplayLink?
    private var offset = SIMD2<Double>(0, 0)
    private var last: CFTimeInterval = 0
    private var needsImage = true
    private lazy var image = UIImage(contentsOfFile: exploreBundle.path(forResource: "clouds", ofType: "png") ?? "")

    /// Bundle file URLs aren't fetched by the image source, so the pixels are handed over directly,
    /// again after every style load.
    func styleLoaded() { needsImage = true }

    nonisolated static func corners(offset: SIMD2<Double>) -> [[Double]] {
        let mLat = 111_320.0, mLon = 111_320.0 * cos(center.lat * .pi / 180)
        let half = tile
        func c(_ x: Double, _ y: Double) -> [Double] {
            [center.lon + (x + offset.x) / mLon, center.lat + (y + offset.y) / mLat]
        }
        return [c(-half, half), c(half, half), c(half, -half), c(-half, -half)]
    }

    func start(map: MapboxMap?) {
        self.map = map
        needsImage = true
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 8, maximum: 15, preferred: 10)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func step(_ link: CADisplayLink) {
        let dt = last == 0 ? 0 : min(link.timestamp - last, 0.3)
        last = link.timestamp
        guard let map else { return }
        if needsImage, let image, (try? map.updateImageSource(withId: CloudShadows.sourceID, image: image)) != nil {
            needsImage = false
        }
        let live = LiveConditions.shared
        let speed = max(1.5, min(live.windSpeed, 9))
        let towards = live.windTowards * .pi / 180
        offset += SIMD2(sin(towards), cos(towards)) * speed * dt
        offset.x = offset.x.truncatingRemainder(dividingBy: Self.tile)
        offset.y = offset.y.truncatingRemainder(dividingBy: Self.tile)
        try? map.setSourceProperty(for: CloudShadows.sourceID, property: "coordinates", value: Self.corners(offset: offset))
    }
}
