import MapboxMaps
import QuartzCore
import simd
import UIKit

/// Toy traffic: cars drive the OSM road network (`ios/tools/bake_road_graph.py`) near the camera,
/// keep right, follow the car ahead, pick turns at junctions and stop at red lights. It also runs
/// the signal cycle that switches the traffic-light models (`StreetFurniture`).
@MainActor
final class TrafficSim: NSObject {
    static let shared = TrafficSim()

    static let sourceID = "traffic"
    static let models = ["car_red", "car_blue", "car_white", "car_yellow", "car_green", "car_black", "car_taxi", "bus"]

    // MARK: Network

    private struct Lane {
        var a: Int, b: Int
        var pts: [SIMD2<Double>]
        var cum: [Double]
        var length: Double
        var speed: Double
        var offset: Double
        var signal: Int
        var weight: Double
        var minX: Double, minY: Double, maxX: Double, maxY: Double
    }

    private var lanes: [Lane] = []
    private var outgoing: [Int: [Int]] = [:]
    private var lat0 = 50.112, lon0 = 8.68
    private lazy var mLon = 111_320.0 * cos(lat0 * .pi / 180)
    private let mLat = 111_320.0

    // MARK: Cars

    private struct Car {
        var id: Int
        var lane: Int
        var prev: Int?
        var next: Int?
        var d: Double
        var speed: Double
        var model: String
        var length: Double
        var cruise: Double
    }

    private var cars: [Car] = []
    private var nextID = 0

    // MARK: Signals

    /// 32 s cycle: group 1 green, all red, group 2 green, all red.
    private let cycle: Double = 32
    private var clock: Double = 0
    private var greenGroup = -1

    private func group(at t: Double) -> Int {
        switch t.truncatingRemainder(dividingBy: cycle) {
        case ..<14: 1
        case ..<16: 0
        case ..<30: 2
        default: 0
        }
    }

    // MARK: Loop

    private weak var map: MapboxMap?
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var sinceManage: Double = 10
    private var area = (minX: 0.0, minY: 0.0, maxX: 0.0, maxY: 0.0)
    private var showing = false

    func start(map: MapboxMap?) {
        self.map = map
        greenGroup = -1
        if lanes.isEmpty { load() }
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    private func load() {
        guard let url = exploreBundle.url(forResource: "frankfurt_roads", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = json["lanes"] as? [[String: Any]] else { return }
        if let o = json["origin"] as? [Double], o.count == 2 { lat0 = o[0]; lon0 = o[1] }
        lanes.reserveCapacity(raw.count)
        for l in raw {
            guard let a = l["a"] as? Int, let b = l["b"] as? Int, let p = l["p"] as? [[Double]], p.count >= 2 else { continue }
            let pts = p.map { SIMD2($0[0], $0[1]) }
            var cum = [0.0]
            for i in 1..<pts.count { cum.append(cum[i - 1] + simd_distance(pts[i - 1], pts[i])) }
            let xs = pts.map(\.x), ys = pts.map(\.y)
            outgoing[a, default: []].append(lanes.count)
            lanes.append(Lane(
                a: a, b: b, pts: pts, cum: cum, length: cum.last!,
                speed: (l["v"] as? Double) ?? 8, offset: (l["o"] as? Double) ?? 0,
                signal: (l["s"] as? Int) ?? 0, weight: (l["w"] as? Double) ?? 1,
                minX: xs.min()!, minY: ys.min()!, maxX: xs.max()!, maxY: ys.max()!))
        }
    }

    private let live = LiveSource(TrafficSim.sourceID, rate: 24, movingRate: 12)
    private var visible: [Int] = []
    private var cumulative: [Double] = []
    private var visibleKey = ""

    func styleLoaded() {
        live.reset()
        greenGroup = -1   // re-apply the signal state to the fresh layer
    }

    @objc private func tick(_ link: CADisplayLink) {
        let dt = last == 0 ? 0 : min(link.timestamp - last, 0.1)
        last = link.timestamp
        guard let map, !lanes.isEmpty else { return }

        clock += dt
        let g = group(at: clock)
        if g != greenGroup {
            greenGroup = g
            let lit: [Any] = ["match", ["get", "g"], g, "signal_green", "signal_red"]
            try? map.setLayerProperty(for: "signal-lights", property: "model-id", value: lit)
        }

        guard map.cameraState.zoom >= 15.3 else {
            if showing { live.clear(map: map); showing = false; cars.removeAll() }
            return
        }

        sinceManage += dt
        if sinceManage > 1 {
            sinceManage = 0
            manage(map)
        }
        step(dt)
        if live.due(map) { publish(cars) }
        showing = true
    }

    // MARK: Spawning

    private func local(_ c: CLLocationCoordinate2D) -> SIMD2<Double> {
        SIMD2((c.longitude - lon0) * mLon, (c.latitude - lat0) * mLat)
    }

    private func manage(_ map: MapboxMap) {
        let bounds = map.coordinateBounds(for: CameraOptions(cameraState: map.cameraState))
        let sw = local(bounds.southwest), ne = local(bounds.northeast)
        let pad = 120.0
        area = (sw.x - pad, sw.y - pad, ne.x + pad, ne.y + pad)

        cars.removeAll { !inside(position(of: $0).p, margin: 60) }

        let key = "\(Int(area.minX / 40)),\(Int(area.minY / 40)),\(Int(area.maxX / 40)),\(Int(area.maxY / 40))"
        if key != visibleKey {
            visibleKey = key
            visible = lanes.indices.filter { i in
                let l = lanes[i]
                return l.maxX >= area.minX && l.minX <= area.maxX && l.maxY >= area.minY && l.minY <= area.maxY
            }
            var sum = 0.0
            cumulative = visible.map { sum += lanes[$0].weight * lanes[$0].length; return sum }
        }
        guard let total = cumulative.last, total > 0 else { return }
        let target = min(160, Int(total / 140))
        var tries = 0
        while cars.count < target && tries < 40 {
            tries += 1
            let r = Double.random(in: 0..<total)
            var lo = 0, hi = cumulative.count - 1
            while lo < hi { let mid = (lo + hi) / 2; if cumulative[mid] < r { lo = mid + 1 } else { hi = mid } }
            spawn(on: visible[lo])
        }
    }

    private func inside(_ p: SIMD2<Double>, margin: Double = 0) -> Bool {
        p.x >= area.minX - margin && p.x <= area.maxX + margin && p.y >= area.minY - margin && p.y <= area.maxY + margin
    }

    private func spawn(on lane: Int) {
        let l = lanes[lane]
        guard l.length > 12 else { return }
        let d = Double.random(in: 4..<(l.length - 4))
        if cars.contains(where: { $0.lane == lane && abs($0.d - d) < 14 }) { return }
        let isBus = l.weight >= 2 && Double.random(in: 0..<1) < 0.07
        let model = isBus ? "bus" : (Double.random(in: 0..<1) < 0.12 ? "car_taxi" : Self.models[Int.random(in: 0..<6)])
        let cruise = l.speed * Double.random(in: 0.6...0.8)
        cars.append(Car(id: nextID, lane: lane, prev: nil, next: chooseNext(after: lane), d: d,
                        speed: cruise, model: model, length: isBus ? 11 : 4.4, cruise: cruise))
        nextID += 1
    }

    private func chooseNext(after lane: Int) -> Int? {
        let l = lanes[lane]
        let options = (outgoing[l.b] ?? []).filter { lanes[$0].b != l.a || lanes[$0].a != l.b }
        let pool = options.isEmpty ? (outgoing[l.b] ?? []) : options
        guard !pool.isEmpty else { return nil }
        // Prefer going roughly straight on, so cars don't zig-zag through every side street.
        let dir = simd_normalize(l.pts[l.pts.count - 1] - l.pts[l.pts.count - 2])
        let scored = pool.map { i -> (Int, Double) in
            let n = lanes[i]
            let ndir = simd_normalize(n.pts[1] - n.pts[0])
            return (i, max(0.15, simd_dot(dir, ndir) + 1.1) * n.weight)
        }
        var r = Double.random(in: 0..<scored.reduce(0) { $0 + $1.1 })
        for (i, w) in scored {
            r -= w
            if r <= 0 { return i }
        }
        return scored.last?.0
    }

    // MARK: Driving

    private func step(_ dt: Double) {
        guard dt > 0 else { return }
        var byLane: [Int: [Int]] = [:]
        for (k, c) in cars.enumerated() { byLane[c.lane, default: []].append(k) }

        var remove = Set<Int>()
        for k in cars.indices {
            var c = cars[k]
            let l = lanes[c.lane]

            // Free road ahead: the nearest car on this lane, or the first one on the next lane.
            var gap = Double.infinity
            for j in byLane[c.lane] ?? [] where j != k && cars[j].d > c.d {
                gap = min(gap, cars[j].d - c.d - (cars[j].length + c.length) / 2)
            }
            if gap == .infinity, let n = c.next {
                for j in byLane[n] ?? [] {
                    gap = min(gap, l.length - c.d + cars[j].d - (cars[j].length + c.length) / 2)
                }
            }
            // Red (or all-red) light at the end of this lane.
            let toStop = l.length - c.d - c.length / 2 - 1.5
            if l.signal != 0, greenGroup != l.signal, toStop > -0.5 {
                if !(greenGroup == 0 && toStop < 3 && c.speed > 4) {   // already committed: clear the junction
                    gap = min(gap, max(0, toStop))
                }
            }

            // Ease off before a sharp turn so the corner curve reads as a turn, not a skid.
            var cornerCap = Double.infinity
            if let n = c.next, l.length - c.d < 25 {
                let turn = simd_dot(endDirection(l), simd_normalize(lanes[n].pts[1] - lanes[n].pts[0]))
                if turn < 0.7 { cornerCap = (turn < 0 ? 3.5 : 5) + sqrt(2 * 2.5 * max(0, l.length - c.d)) }
            }

            let brake = 4.0, accel = 1.8
            let safe = gap.isFinite ? sqrt(max(0, 2 * brake * max(0, gap - 2.5))) : c.cruise
            let target = min(c.cruise, safe, cornerCap)
            c.speed = c.speed < target ? min(target, c.speed + accel * dt) : max(target, c.speed - brake * 1.5 * dt)
            c.d += c.speed * dt

            while c.d > lanes[c.lane].length {
                c.d -= lanes[c.lane].length
                guard let n = c.next else { remove.insert(c.id); break }
                c.prev = c.lane
                c.lane = n
                c.next = chooseNext(after: n)
                c.cruise = lanes[n].speed * Double.random(in: 0.6...0.8)
            }
            cars[k] = c
        }
        if !remove.isEmpty { cars.removeAll { remove.contains($0.id) } }
    }

    // MARK: Output

    private func endDirection(_ l: Lane) -> SIMD2<Double> {
        simd_normalize(l.pts[l.pts.count - 1] - l.pts[l.pts.count - 2])
    }

    /// One straight piece of a lane, already shifted to the driving side.
    private struct Piece {
        var a: SIMD2<Double>, b: SIMD2<Double>, dir: SIMD2<Double>, length: Double
    }

    private func piece(_ lane: Int, _ i: Int) -> Piece {
        let l = lanes[lane]
        let dir = simd_normalize(l.pts[i] - l.pts[i - 1])
        let right = SIMD2(dir.y, -dir.x) * l.offset
        return Piece(a: l.pts[i - 1] + right, b: l.pts[i] + right, dir: dir, length: l.cum[i] - l.cum[i - 1])
    }

    /// Corners are rounded: within `r` of a vertex (also across a junction into the next or from the
    /// previous lane) the car follows a quadratic curve instead of snapping to the new heading.
    private func position(of c: Car) -> (p: SIMD2<Double>, heading: Double) {
        let l = lanes[c.lane]
        let d = min(max(c.d, 0), l.length)
        var i = 1
        while i < l.cum.count - 1 && l.cum[i] < d { i += 1 }
        let here = piece(c.lane, i)
        let s = d - l.cum[i - 1], e = l.cum[i] - d

        func curve(_ pin: Piece, _ pout: Piece, u: Double) -> (SIMD2<Double>, Double)? {
            let r = min(7, pin.length / 2, pout.length / 2)
            guard r > 0.5, simd_dot(pin.dir, pout.dir) < 0.999 else { return nil }
            let p0 = pin.b - pin.dir * r, p2 = pout.a + pout.dir * r
            let p1 = (pin.b + pout.a) / 2
            let t = u
            let p = (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2
            let v = 2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)
            return (p, atan2(v.y, v.x) * 180 / .pi)
        }

        // Approaching the end of this piece.
        let nextPiece: Piece? = i < l.pts.count - 1 ? piece(c.lane, i + 1)
            : c.next.map { piece($0, 1) }
        if let np = nextPiece {
            let r = min(7, here.length / 2, np.length / 2)
            if e < r, let out = curve(here, np, u: (r - e) / (2 * r)) { return out }
        }
        // Leaving the start of this piece.
        let prevPiece: Piece? = i > 1 ? piece(c.lane, i - 1)
            : c.prev.map { piece($0, lanes[$0].pts.count - 1) }
        if let pp = prevPiece {
            let r = min(7, here.length / 2, pp.length / 2)
            if s < r, let out = curve(pp, here, u: 0.5 + s / (2 * r)) { return out }
        }
        let t = s / max(here.length, 0.001)
        return (here.a + (here.b - here.a) * t, atan2(here.dir.y, here.dir.x) * 180 / .pi)
    }

    private func publish(_ list: [Car]) {
        guard let map else { return }
        let features: [Feature] = list.map { c in
            let (p, h) = position(of: c)
            var f = Feature(geometry: .point(Point(CLLocationCoordinate2D(latitude: lat0 + p.y / mLat, longitude: lon0 + p.x / mLon))))
            f.identifier = .string("car-\(c.id)")
            f.properties = ["m": .string(c.model), "r": .array([.number(0), .number(0), .number(-h)])]
            return f
        }
        live.publish(features, map: map)
    }
}

/// Map layer for the simulated vehicles.
struct Traffic: MapStyleContent {
    var mood: MapMood = .day

    static var scale: Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            15.5
            [1.3, 1.3, 1.3]
            18
            [1.0, 1.0, 1.0]
        }
    }

    var body: some MapStyleContent {
        GeoJSONSource.live(TrafficSim.sourceID)

        Model(id: "car_red", uri: PuffyTrees.model("car_red"))
        Model(id: "car_blue", uri: PuffyTrees.model("car_blue"))
        Model(id: "car_white", uri: PuffyTrees.model("car_white"))
        Model(id: "car_yellow", uri: PuffyTrees.model("car_yellow"))
        Model(id: "car_green", uri: PuffyTrees.model("car_green"))
        Model(id: "car_black", uri: PuffyTrees.model("car_black"))
        Model(id: "car_taxi", uri: PuffyTrees.model("car_taxi"))
        Model(id: "bus", uri: PuffyTrees.model("bus"))
        Model(id: "car_lights", uri: PuffyTrees.model("car_lights"))
        Model(id: "bus_lights", uri: PuffyTrees.model("bus_lights"))

        ModelLayer(id: "traffic", source: TrafficSim.sourceID)
            .slot(.middle)
            .minZoom(15.3)
            .modelId(Exp(.get) { "m" })
            .modelType(.common3d)
            .modelScale(Self.scale)
            .modelRotation(Exp(.get) { "r" })
            .modelCastShadows(true)
            .modelReceiveShadows(true)

        if mood != .day {
            ModelLayer(id: "traffic-lights", source: TrafficSim.sourceID)
                .slot(.middle)
                .minZoom(15.3)
                .modelId(Exp(.match) { Exp(.get) { "m" }; "bus"; "bus_lights"; "car_lights" })
                .modelType(.common3d)
                .modelScale(Self.scale)
                .modelRotation(Exp(.get) { "r" })
                .modelCastShadows(false)
                .modelEmissiveStrength(mood == .night ? 2 : 1.2)
        }
    }
}
