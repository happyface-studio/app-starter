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

/// Soft cloud shadows: clusters of heavily blurred, ground-aligned circles sized in metres, laid out
/// on a repeating 2 km tile around the city and drifted with the live wind via `circle-translate`.
/// The drift wraps every tile, which is invisible because the neighbouring tiles match.
struct CloudShadows: MapStyleContent {
    var mood: MapMood
    var sky: Sky

    static let sourceID = "cloud-shadows"
    static let layerID = "cloud-shadows"

    private var opacity: Double {
        guard mood == .day || mood == .dawn || mood == .dusk else { return 0 }
        return switch sky {
        case .clear: 0.12
        case .partly: 0.24
        case .cloudy, .fog: 0.16
        default: 0.1
        }
    }

    var body: some MapStyleContent {
        GeoJSONSource(id: Self.sourceID)
            .data(.featureCollection(CloudDrift.puffs))

        CircleLayer(id: Self.layerID, source: Self.sourceID)
            .slot(.middle)
            .circlePitchAlignment(.map)
            .circlePitchScale(.map)
            .circleTranslateAnchor(.map)
            .circleColor(StyleColor(UIColor(red: 0.10, green: 0.12, blue: 0.26, alpha: 1)))
            .circleBlur(0.85)
            .circleOpacity(opacity)
            .circleOpacityTransition(StyleTransition(duration: 3, delay: 0))
            .circleEmissiveStrength(1)
            // Radius in metres -> pixels: px = m * 2^z / (78271.5 * cos(lat)).
            .circleRadius(Exp(.interpolate) {
                Exp(.exponential) { 2 }
                Exp(.zoom)
                10
                Exp(.product) { Exp(.get) { "r" }; CloudDrift.pixelsPerMetre(atZoom: 10) }
                20
                Exp(.product) { Exp(.get) { "r" }; CloudDrift.pixelsPerMetre(atZoom: 20) }
            })
    }
}

@MainActor
final class CloudDrift: NSObject {
    static let shared = CloudDrift()

    nonisolated static let tile = 2000.0
    nonisolated private static let center = (lat: 50.112, lon: 8.68)

    nonisolated static func pixelsPerMetre(atZoom z: Double) -> Double {
        pow(2, z) / (78_271.517 * cos(center.lat * .pi / 180))
    }

    /// Cloud puffs on a 6x6 grid of identical 2 km tiles (covers the city with room to drift).
    nonisolated static let puffs: FeatureCollection = {
        var rng = SeededRandom(seed: 7)
        var pattern: [(x: Double, y: Double, r: Double)] = []
        for _ in 0..<15 {
            let cx = rng.next() * tile, cy = rng.next() * tile
            for _ in 0..<(6 + Int(rng.next() * 5)) {
                pattern.append((cx + (rng.next() - 0.5) * 260, cy + (rng.next() - 0.5) * 150, 70 + rng.next() * 90))
            }
        }
        let mLat = 111_320.0, mLon = 111_320.0 * cos(center.lat * .pi / 180)
        var features: [Feature] = []
        for tx in -3..<3 {
            for ty in -3..<3 {
                for p in pattern {
                    let x = Double(tx) * tile + p.x, y = Double(ty) * tile + p.y
                    var f = Feature(geometry: .point(Point(CLLocationCoordinate2D(
                        latitude: center.lat + y / mLat, longitude: center.lon + x / mLon))))
                    f.properties = ["r": .number(p.r)]
                    features.append(f)
                }
            }
        }
        return FeatureCollection(features: features)
    }()

    private weak var map: MapboxMap?
    private var link: CADisplayLink?
    private var offset = SIMD2<Double>(0, 0)
    private var last: CFTimeInterval = 0

    func start(map: MapboxMap?) {
        self.map = map
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 20)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func styleLoaded() {}

    @objc private func step(_ link: CADisplayLink) {
        let dt = last == 0 ? 0 : min(link.timestamp - last, 0.3)
        last = link.timestamp
        guard let map else { return }
        let live = LiveConditions.shared
        let speed = max(1.5, min(live.windSpeed, 9))
        let towards = live.windTowards * .pi / 180
        offset += SIMD2(sin(towards), cos(towards)) * speed * dt
        offset.x = offset.x.truncatingRemainder(dividingBy: Self.tile)
        offset.y = offset.y.truncatingRemainder(dividingBy: Self.tile)
        let ppm = Self.pixelsPerMetre(atZoom: map.cameraState.zoom)
        // circle-translate is in pixels, y pointing down (south) with the map anchor.
        try? map.setLayerProperty(for: CloudShadows.layerID, property: "circle-translate",
                                  value: [offset.x * ppm, -offset.y * ppm])
    }
}

/// Small deterministic PRNG so every launch gets the same cloud layout.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }
}
