import MapboxMaps
import simd
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

    private weak var map: MapboxMap?

    func styleLoaded(map: MapboxMap?) {
        lastKey = ""
        self.map = map
        // After a style change the map may already be idle before the new buildings are drawn.
        for delay in [1.5, 4.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, let map = self.map else { return }
                self.refresh(map: map)
            }
        }
    }

    /// `-probe x,y;x,y` (screen points) prints what the building layers have there (look debugging).
    private func probe(_ map: MapboxMap) {
        guard let spec = UserDefaults.standard.string(forKey: "probe") else { return }
        for pair in spec.split(separator: ";") {
            let v = pair.split(separator: ",").compactMap { Double($0) }
            guard v.count == 2 else { continue }
            let pt = CGPoint(x: v[0], y: v[1])
            _ = map.queryRenderedFeatures(with: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4), options: RenderedQueryOptions(layerIds: nil, filter: nil)) { result in
                guard case .success(let hits) = result else { return }
                for h in hits.prefix(6) {
                    print("PROBE", pt, h.queriedFeature.sourceLayer ?? "-", h.layers, String(describing: h.queriedFeature.feature.properties))
                }
            }
        }
    }

    /// Call when the camera settles.
    func refresh(map: MapboxMap) {
        probe(map)
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
                guard case .success(let hits) = result, !hits.isEmpty else {
                    self.lastKey = ""   // tiles not drawn yet (e.g. right after a style change): try again on the next idle
                    return
                }
                self.build(hits.map(\.queriedFeature.feature), map: map, origin: cam.center)
            }
        }
    }

    private func build(_ buildings: [Feature], map: MapboxMap, origin: CLLocationCoordinate2D) {
        if UserDefaults.standard.bool(forKey: "dumpTypes") {
            var counts: [String: Int] = [:]
            for b in buildings {
                let t: String = switch b.properties?["type"] ?? nil { case .string(let s)?: s; default: "nil" }
                counts[t, default: 0] += 1
            }
            print("BUILDING TYPES", counts.sorted { $0.value > $1.value }.prefix(25), "ids:", buildings.prefix(5).map { String(describing: $0.identifier) })
        }
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
            let du: SIMD2<Double> = u * (w / 2), dv: SIMD2<Double> = v * (d / 2)
            let p0: SIMD2<Double> = c - du - dv
            let p1: SIMD2<Double> = c + du - dv
            let p2: SIMD2<Double> = c + du + dv
            let p3: SIMD2<Double> = c - du + dv
            let ring: [CLLocationCoordinate2D] = [p0, p1, p2, p3, p0].map(coord)
            var f = Feature(geometry: .polygon(Polygon([ring])))
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
            let sum: SIMD2<Double> = pts.reduce(SIMD2<Double>(0, 0), +)
            let centre: SIMD2<Double> = sum / Double(pts.count)
            var area = 0.0
            for i in pts.indices { let a = pts[i], c = pts[(i + 1) % pts.count]; area += a.x * c.y - c.x * a.y }
            guard abs(area / 2) > 60 else { continue }

            // A stack just inside the outward corners, plus one every ~11 m along long walls (party walls).
            // Inner corners of L- and U-shaped blocks get none, which kept stacks from piling up.
            var stacks = 0
            for i in pts.indices where stacks < 5 {
                let p = pts[i], a = pts[(i + pts.count - 1) % pts.count], c = pts[(i + 1) % pts.count]
                let e1: SIMD2<Double> = simd_normalize(p - a), e2: SIMD2<Double> = simd_normalize(c - p)
                guard simd_length(p - a) > 4, simd_length(c - p) > 4 else { continue }
                let turn = (e1.x * e2.y - e1.y * e2.x) * (area > 0 ? 1.0 : -1.0)
                let corner = turn > 0.6
                if corner {
                    let inward: SIMD2<Double> = simd_normalize(centre - p)
                    let s0: SIMD2<Double> = p + inward * 1.6
                    let side: SIMD2<Double> = e2 * 0.25
                    box(s0, e2, 1.1, 0.7, base: h - 0.5, top: h + 1.5, kind: "stack")
                    box(s0 + side, e2, 0.24, 0.24, base: h + 1.5, top: h + 1.95, kind: "pot")
                    box(s0 - side, e2, 0.24, 0.24, base: h + 1.5, top: h + 1.95, kind: "pot")
                    stacks += 1
                }
                let len = simd_length(c - p)
                if len > 16 {
                    let n = Int(len / 11)
                    let inward: SIMD2<Double> = SIMD2(-e2.y, e2.x) * (area > 0 ? 1.0 : -1.0)
                    for k in 1..<max(n, 2) where stacks < 5 {
                        let along: Double = len * Double(k) / Double(n)
                        let q: SIMD2<Double> = p + e2 * along + inward * 1.3
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
