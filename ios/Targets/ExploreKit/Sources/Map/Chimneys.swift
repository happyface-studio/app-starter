import MapboxMaps
import UIKit

/// Chimney stacks with terracotta pots on the mansard roofs of plain buildings. They are worked out
/// on the device from the buildings on screen whenever the camera comes to rest, so they always sit
/// on the roofs Mapbox actually draws (and only those).
@MainActor
final class Chimneys {
    static let shared = Chimneys()
    static let source = "chimneys"

    private let mLat = 111_320.0
    private var mLon: Double { 111_320.0 * cos(50.11 * .pi / 180) }
    private var lastKey = ""
    private var pending = false

    func styleLoaded() { lastKey = "" }

    /// Call when the camera settles.
    func refresh(map: MapboxMap) {
        let cam = map.cameraState
        guard cam.zoom >= 16.3 else {
            if !lastKey.isEmpty { publish([], map: map); lastKey = "" }
            return
        }
        let key = String(format: "%.4f,%.4f,%.1f,%.0f", cam.center.latitude, cam.center.longitude, cam.zoom, cam.bearing)
        guard key != lastKey, !pending else { return }
        lastKey = key
        pending = true
        let size = UIScreen.main.bounds.size
        let rect = CGRect(origin: .zero, size: size)
        let options = RenderedQueryOptions(layerIds: ["plain-buildings-mansard"], filter: nil)
        _ = map.queryRenderedFeatures(with: rect, options: options) { [weak self, weak map] result in
            Task { @MainActor in
                guard let self, let map else { return }
                self.pending = false
                guard case .success(let hits) = result else { return }
                self.build(hits.map(\.queriedFeature.feature), map: map, origin: cam.center)
            }
        }
    }

    private func build(_ buildings: [Feature], map: MapboxMap, origin: CLLocationCoordinate2D) {
        var seen = Set<String>()
        var out: [Feature] = []
        func local(_ c: CLLocationCoordinate2D) -> SIMD2<Double> {
            SIMD2((c.longitude - origin.longitude) * mLon, (c.latitude - origin.latitude) * mLat)
        }
        func coord(_ p: SIMD2<Double>) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: origin.latitude + p.y / mLat, longitude: origin.longitude + p.x / mLon)
        }
        func box(_ c: SIMD2<Double>, _ u: SIMD2<Double>, _ w: Double, _ d: Double, base: Double, top: Double, kind: String) {
            let v = SIMD2(-u.y, u.x)
            let ring = [c - u * w / 2 - v * d / 2, c + u * w / 2 - v * d / 2, c + u * w / 2 + v * d / 2, c - u * w / 2 + v * d / 2]
            var f = Feature(geometry: .polygon(Polygon([(ring + [ring[0]]).map(coord)])))
            f.properties = ["k": .string(kind), "b": .number(base), "h": .number(top)]
            out.append(f)
        }

        for b in buildings {
            guard out.count < 6000, case .polygon(let poly)? = b.geometry,
                  case .number(let h)? = b.properties?["height"] ?? nil else { continue }
            let id: String = switch b.identifier {
            case .string(let s)?: s
            case .number(let n)?: "\(n)"
            default: "\(poly.outerRing.coordinates.first?.latitude ?? 0)"
            }
            guard seen.insert(id).inserted else { continue }
            var pts = poly.outerRing.coordinates.map(local)
            if pts.count > 1, pts.first == pts.last { pts.removeLast() }
            guard pts.count >= 4 else { continue }
            let centre = pts.reduce(SIMD2<Double>(0, 0), +) / Double(pts.count)
            var area = 0.0
            for i in pts.indices { let a = pts[i], c = pts[(i + 1) % pts.count]; area += a.x * c.y - c.x * a.y }
            guard abs(area / 2) > 60 else { continue }

            // A stack just inside every real corner, plus one every ~11 m along long walls (party walls).
            var stacks = 0
            for i in pts.indices where stacks < 8 {
                let p = pts[i], a = pts[(i + pts.count - 1) % pts.count], c = pts[(i + 1) % pts.count]
                let e1 = simd_normalize(p - a), e2 = simd_normalize(c - p)
                guard simd_length(p - a) > 4, simd_length(c - p) > 4 else { continue }
                let corner = abs(e1.x * e2.y - e1.y * e2.x) > 0.6
                if corner {
                    let inward = simd_normalize(centre - p)
                    box(p + inward * 1.6, e2, 1.1, 0.7, base: h - 0.5, top: h + 1.5, kind: "stack")
                    box(p + inward * 1.6 + e2 * 0.25, e2, 0.24, 0.24, base: h + 1.5, top: h + 1.95, kind: "pot")
                    box(p + inward * 1.6 - e2 * 0.25, e2, 0.24, 0.24, base: h + 1.5, top: h + 1.95, kind: "pot")
                    stacks += 1
                }
                let len = simd_length(c - p)
                if len > 16 {
                    let n = Int(len / 11)
                    let inward = SIMD2(-e2.y, e2.x) * (area > 0 ? 1 : -1)
                    for k in 1..<max(n, 2) where stacks < 8 {
                        let q = p + e2 * (len * Double(k) / Double(n)) + inward * 1.3
                        box(q, e2, 0.9, 0.6, base: h - 0.5, top: h + 1.3, kind: "stack")
                        box(q, e2, 0.24, 0.24, base: h + 1.3, top: h + 1.7, kind: "pot")
                        stacks += 1
                    }
                }
            }
        }
        publish(out, map: map)
    }

    private func publish(_ features: [Feature], map: MapboxMap) {
        map.updateGeoJSONSource(withId: Self.source, geoJSON: .featureCollection(FeatureCollection(features: features)))
    }
}

struct ChimneyLayers: MapStyleContent {
    var palette: CityPalette

    var body: some MapStyleContent {
        GeoJSONSource(id: Chimneys.source).data(.featureCollection(FeatureCollection(features: [])))

        FillExtrusionLayer(id: "chimney-stacks", source: Chimneys.source)
            .slot(.middle)
            .minZoom(16.3)
            .filter(Exp(.eq) { Exp(.get) { "k" }; "stack" })
            .fillExtrusionColor(StyleColor(UIColor(hex: palette.buildings).blended(with: UIColor(hex: 0xB07A5A), amount: 0.25)))
            .fillExtrusionBase(Exp(.get) { "b" })
            .fillExtrusionHeight(Exp(.get) { "h" })
            .fillExtrusionVerticalGradient(false)
            .fillExtrusionCastShadows(true)

        FillExtrusionLayer(id: "chimney-pots", source: Chimneys.source)
            .slot(.middle)
            .minZoom(16.3)
            .filter(Exp(.eq) { Exp(.get) { "k" }; "pot" })
            .fillExtrusionColor(StyleColor(UIColor(hex: 0xC2714F)))
            .fillExtrusionBase(Exp(.get) { "b" })
            .fillExtrusionHeight(Exp(.get) { "h" })
            .fillExtrusionVerticalGradient(false)
    }
}
