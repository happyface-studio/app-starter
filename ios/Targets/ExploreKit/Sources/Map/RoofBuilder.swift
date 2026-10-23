import MapboxMaps
import simd
import UIKit

/// Pitched roofs and rooftop clutter for the buildings Standard draws flat (`PlainBuildings`).
///
/// Mapbox can't give an extrusion a sloped top, and OSM rarely knows building heights, so the
/// roofs are made on the device from what the map actually draws: when the camera comes to rest,
/// the buildings on screen are read back with their rendered height, and each pitched-roof house
/// gets a stack of narrowing slabs along its long side (gabled), from all sides (hipped,
/// pyramidal) or from one side (skillion). At toy scale the steps read as a roof.
/// Flat roofs get stair housings, vents and the odd row of solar panels.
@MainActor
final class RoofBuilder {
    static let shared = RoofBuilder()
    static let source = "roof-extras"

    var palette: CityPalette = .mayfair

    private weak var map: MapboxMap?
    private var timer: Timer?
    private var lastCamera: CameraState?
    private var stillTicks = 0
    private var builtKey = ""
    private var pending = false

    private let mLat = 111_320.0
    private var mLon: Double { 111_320.0 * cos(50.11 * .pi / 180) }

    func start(map: MapboxMap?) {
        self.map = map
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            Task { @MainActor in RoofBuilder.shared.tick() }
        }
    }

    func styleLoaded(palette: CityPalette) {
        self.palette = palette
        builtKey = ""
        stillTicks = 0
    }

    /// Builds once the camera has been still for one tick (the map is never "idle" with traffic running).
    private func tick() {
        guard let map, !pending else { return }
        let cam = map.cameraState
        if let last = lastCamera, last == cam { stillTicks += 1 } else { stillTicks = 0 }
        lastCamera = cam
        guard stillTicks >= 1 else { return }
        guard cam.zoom >= 15.8 else {
            if builtKey != "off" { publish([], map: map); builtKey = "off" }
            return
        }
        let key = String(format: "%.5f,%.5f,%.2f,%.0f,%.0f", cam.center.latitude, cam.center.longitude, cam.zoom, cam.bearing, cam.pitch)
        guard key != builtKey else { return }
        pending = true
        let rect = CGRect(origin: .zero, size: UIScreen.main.bounds.size)
        let options = RenderedQueryOptions(layerIds: ["plain-buildings-roof"], filter: nil)
        _ = map.queryRenderedFeatures(with: rect, options: options) { [weak self] result in
            Task { @MainActor in
                guard let self, let map = self.map else { return }
                self.pending = false
                guard case .success(let hits) = result, !hits.isEmpty else { return }   // not drawn yet: retry next tick
                self.builtKey = key
                self.build(hits.map(\.queriedFeature.feature), map: map, origin: cam.center)
            }
        }
    }

    // MARK: Geometry

    private struct Building {
        var id: Int
        var partOf: Int
        var height: Double
        var ring: [SIMD2<Double>]
        var area: Double
    }

    private func build(_ features: [Feature], map: MapboxMap, origin: CLLocationCoordinate2D) {
        func local(_ c: CLLocationCoordinate2D) -> SIMD2<Double> {
            SIMD2((c.longitude - origin.longitude) * mLon, (c.latitude - origin.latitude) * mLat)
        }
        // A building split across tiles comes back in pieces; keep the largest.
        var byID: [Int: Building] = [:]
        for f in features {
            guard case .number(let idD)? = f.identifier, case .polygon(let poly)? = f.geometry,
                  case .number(let h)? = f.properties?["height"] ?? nil else { continue }
            if case .string(let t)? = f.properties?["type"] ?? nil, t == "building:part" { continue }
            if case .number(let mh)? = f.properties?["min_height"] ?? nil, mh > 0 { continue }
            let id = Int(idD)
            var ring = poly.outerRing.coordinates.map(local)
            if ring.count > 1, ring.first == ring.last { ring.removeLast() }
            guard ring.count >= 3 else { continue }
            let a = abs(Self.area(ring))
            if let old = byID[id], old.area >= a { continue }
            var part = id
            if case .number(let b)? = f.properties?["building_id"] ?? nil { part = Int(b) }
            byID[id] = Building(id: id, partOf: part, height: h, ring: ring, area: a)
        }

        var out: [Feature] = []
        out.reserveCapacity(byID.count * 4)
        func emit(_ ring: [SIMD2<Double>], base: Double, top: Double, colour: String) {
            guard ring.count >= 3 else { return }
            let coords = (ring + [ring[0]]).map {
                CLLocationCoordinate2D(latitude: origin.latitude + $0.y / mLat, longitude: origin.longitude + $0.x / mLon)
            }
            var f = Feature(geometry: .polygon(Polygon([coords])))
            f.properties = ["b": .number(base), "h": .number(top), "c": .string(colour)]
            out.append(f)
        }

        for b in byID.values where b.area > 25 {
            let top = b.height + PlainBuildings.jitter(id: b.id)
            let shape = BuildingLook.roofShape(id: b.id, height: b.height)
            if shape == "flat" {
                clutter(b, top: top, emit: emit)
            } else {
                let colour = BuildingLook.roofColour(id: b.id)
                    ?? FacadeTile.pitchedRoof(palette, id: b.id).cssHex
                roof(b, shape: shape, top: top, colour: colour, emit: emit)
            }
            if out.count > 12_000 { break }
        }
        publish(out, map: map)
    }

    /// Principal axes of the footprint: `u` along the long side.
    private func frame(_ ring: [SIMD2<Double>]) -> (c: SIMD2<Double>, u: SIMD2<Double>, v: SIMD2<Double>,
                                                     a: ClosedRange<Double>, b: ClosedRange<Double>) {
        let c = ring.reduce(SIMD2<Double>(0, 0), +) / Double(ring.count)
        var sxx = 0.0, syy = 0.0, sxy = 0.0
        for p in ring { let d = p - c; sxx += d.x * d.x; syy += d.y * d.y; sxy += d.x * d.y }
        let ang = 0.5 * atan2(2 * sxy, sxx - syy)
        var u = SIMD2(cos(ang), sin(ang)), v = SIMD2(-sin(ang), cos(ang))
        func extent(_ axis: SIMD2<Double>) -> ClosedRange<Double> {
            let ds = ring.map { simd_dot($0 - c, axis) }
            return ds.min()!...ds.max()!
        }
        var a = extent(u), b = extent(v)
        if a.upperBound - a.lowerBound < b.upperBound - b.lowerBound { swap(&u, &v); swap(&a, &b) }
        // Narrow, deep terrace houses (Gründerzeit plots) have the ridge parallel to the street, i.e.
        // across the long side; detached houses keep it along the long side.
        let long = a.upperBound - a.lowerBound, short = b.upperBound - b.lowerBound
        if short < 14, long > 15, long > short * 1.2 { swap(&u, &v); swap(&a, &b) }
        return (c, u, v, a, b)
    }

    private func roof(_ b: Building, shape: String, top: Double,
                      colour: String, emit: ([SIMD2<Double>], Double, Double, String) -> Void) {
        let f = frame(b.ring)
        let halfW = (f.b.upperBound - f.b.lowerBound) / 2, bMid = (f.b.upperBound + f.b.lowerBound) / 2
        let halfL = (f.a.upperBound - f.a.lowerBound) / 2, aMid = (f.a.upperBound + f.a.lowerBound) / 2
        guard halfW > 1.5 else { return }
        let rise = min(halfW * 0.8, 5.5)
        let tiers = rise > 3 ? 8 : 6
        let step = rise / Double(tiers)
        for k in 0..<tiers {
            let w = halfW * Double(tiers - k) / Double(tiers)
            var ring = b.ring
            switch shape {
            case "skillion":
                ring = Self.clip(ring, f.c, -f.v, -(f.b.lowerBound + 2 * halfW * Double(k) / Double(tiers)))
            default:
                ring = Self.clip(ring, f.c, f.v, bMid + w)
                ring = Self.clip(ring, f.c, -f.v, -(bMid - w))
                if shape == "hipped" || shape == "pyramidal" {
                    let l = max(0.8, halfL - (halfW - w))
                    ring = Self.clip(ring, f.c, f.u, aMid + l)
                    ring = Self.clip(ring, f.c, -f.u, -(aMid - l))
                }
            }
            emit(ring, top + Double(k) * step, top + Double(k + 1) * step, colour)
        }
    }

    /// Stair housing, vents and solar panels on flat roofs, placed from the building id so they
    /// stay put between rebuilds.
    private func clutter(_ b: Building, top: Double, emit: ([SIMD2<Double>], Double, Double, String) -> Void) {
        guard b.area > 220, b.height >= 8 else { return }
        let f = frame(b.ring)
        var seed = UInt64(truncatingIfNeeded: b.id) &* 0x9E37_79B9_7F4A_7C15
        func rnd() -> Double {
            seed ^= seed >> 12; seed ^= seed << 25; seed ^= seed >> 27
            return Double((seed &* 0x2545_F491_4F6C_DD1D) >> 11) / Double(1 << 53)
        }
        func box(_ at: SIMD2<Double>, _ len: Double, _ wid: Double) -> [SIMD2<Double>] {
            let du = f.u * (len / 2), dv = f.v * (wid / 2)
            return [at - du - dv, at + du - dv, at + du + dv, at - du + dv]
        }
        func spot(margin: Double) -> SIMD2<Double> {
            let a = f.a.lowerBound + margin + rnd() * max(0, f.a.upperBound - f.a.lowerBound - 2 * margin)
            let bb = f.b.lowerBound + margin + rnd() * max(0, f.b.upperBound - f.b.lowerBound - 2 * margin)
            return f.c + f.u * a + f.v * bb
        }
        func fits(_ r: [SIMD2<Double>]) -> Bool { r.allSatisfy { Self.inside($0, b.ring) } }

        let housing = box(spot(margin: 3), 3.2, 2.6)
        if fits(housing) { emit(housing, top, top + 2.6, "#C9C6C0") }
        for _ in 0..<(2 + Int(rnd() * 3)) {
            let vent = box(spot(margin: 1.5), 1.0, 1.0)
            if fits(vent) { emit(vent, top, top + 0.9, "#AAA7A2") }
        }
        if b.area > 900, rnd() < 0.6 {
            let rows = 2 + Int(rnd() * 3)
            let start = spot(margin: 4)
            for r in 0..<rows {
                let panel = box(start + f.v * (Double(r) * 2.4), 6.0, 1.6)
                if fits(panel) { emit(panel, top, top + 0.35, "#3E4A6B") }
            }
        }
    }

    // MARK: Helpers

    private static func area(_ r: [SIMD2<Double>]) -> Double {
        var s = 0.0
        for i in r.indices { let a = r[i], b = r[(i + 1) % r.count]; s += a.x * b.y - b.x * a.y }
        return s / 2
    }

    /// Sutherland–Hodgman: keeps the part of `ring` where dot(p - c, n) <= d.
    private static func clip(_ ring: [SIMD2<Double>], _ c: SIMD2<Double>, _ n: SIMD2<Double>, _ d: Double) -> [SIMD2<Double>] {
        guard ring.count >= 3 else { return [] }
        var out: [SIMD2<Double>] = []
        out.reserveCapacity(ring.count + 4)
        for i in ring.indices {
            let p = ring[i], q = ring[(i + 1) % ring.count]
            let dp = simd_dot(p - c, n) - d, dq = simd_dot(q - c, n) - d
            if dp <= 0 { out.append(p) }
            if (dp <= 0) != (dq <= 0) {
                let t = dp / (dp - dq)
                out.append(p + (q - p) * t)
            }
        }
        return out
    }

    private static func inside(_ p: SIMD2<Double>, _ ring: [SIMD2<Double>]) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in ring.indices {
            let a = ring[i], b = ring[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y + 1e-12) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    private func publish(_ features: [Feature], map: MapboxMap) {
        map.updateGeoJSONSource(withId: Self.source, geoJSON: .featureCollection(FeatureCollection(features: features)))
    }
}

/// Map layer for `RoofBuilder`'s roofs and rooftop clutter.
struct RoofExtras: MapStyleContent {
    var body: some MapStyleContent {
        GeoJSONSource(id: RoofBuilder.source).data(.featureCollection(FeatureCollection(features: [])))

        FillExtrusionLayer(id: "roof-extras", source: RoofBuilder.source)
            .slot(.middle)
            .minZoom(15.8)
            .fillExtrusionColor(Exp(.toColor) { Exp(.get) { "c" } })
            .fillExtrusionBase(Exp(.get) { "b" })
            .fillExtrusionHeight(Exp(.get) { "h" })
            .fillExtrusionVerticalGradient(false)
            .fillExtrusionCastShadows(true)
            .fillExtrusionOpacity(Exp(.interpolate) {
                Exp(.linear)
                Exp(.zoom)
                15.8
                0
                16.2
                1
            })
    }
}
