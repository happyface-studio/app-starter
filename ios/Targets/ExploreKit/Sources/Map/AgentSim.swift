import MapboxMaps
import QuartzCore
import simd
import UIKit

/// Directed lanes baked by `ios/tools/bake_life.py` / `bake_road_graph.py` (local metre frame).
struct LaneNetwork {
    struct Lane {
        var a: Int, b: Int
        var pts: [SIMD2<Double>]
        var cum: [Double]
        var length: Double
        var speed: Double
        var stop: Bool
        var weight: Double
        var minX: Double, minY: Double, maxX: Double, maxY: Double
    }

    var lanes: [Lane] = []
    var outgoing: [Int: [Int]] = [:]
    var lat0 = 50.112, lon0 = 8.68
    var mLon: Double { 111_320.0 * cos(lat0 * .pi / 180) }
    let mLat = 111_320.0

    init(resource: String) {
        guard let url = exploreBundle.url(forResource: resource, withExtension: "json"),
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
            lanes.append(Lane(a: a, b: b, pts: pts, cum: cum, length: cum.last!,
                              speed: (l["v"] as? Double) ?? 1.3, stop: ((l["s"] as? Int) ?? 0) != 0,
                              weight: (l["w"] as? Double) ?? 1,
                              minX: xs.min()!, minY: ys.min()!, maxX: xs.max()!, maxY: ys.max()!))
        }
    }

    func local(_ c: CLLocationCoordinate2D) -> SIMD2<Double> {
        SIMD2((c.longitude - lon0) * mLon, (c.latitude - lat0) * mLat)
    }

    func coordinate(_ p: SIMD2<Double>) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat0 + p.y / mLat, longitude: lon0 + p.x / mLon)
    }

    /// Point and heading (degrees, counter-clockwise from east) at distance `d` along a lane,
    /// shifted `offset` metres to the right of travel.
    func sample(_ lane: Int, _ d: Double, offset: Double) -> (p: SIMD2<Double>, heading: Double) {
        let l = lanes[lane]
        let d = min(max(d, 0), l.length)
        var i = 1
        while i < l.cum.count - 1 && l.cum[i] < d { i += 1 }
        let a = l.pts[i - 1], b = l.pts[i]
        let t = (d - l.cum[i - 1]) / max(l.cum[i] - l.cum[i - 1], 0.001)
        let dir = simd_normalize(b - a)
        return (a + (b - a) * t + SIMD2(dir.y, -dir.x) * offset, atan2(dir.y, dir.x) * 180 / .pi)
    }

    /// Next lane at the end of `lane`: no U-turns unless it's a dead end, mostly straight on.
    func next(after lane: Int) -> Int? {
        let l = lanes[lane]
        let all = outgoing[l.b] ?? []
        let options = all.filter { lanes[$0].b != l.a }
        let pool = options.isEmpty ? all : options
        guard !pool.isEmpty else { return nil }
        let dir = simd_normalize(l.pts[l.pts.count - 1] - l.pts[l.pts.count - 2])
        let scored = pool.map { i -> (Int, Double) in
            let n = lanes[i]
            return (i, max(0.2, simd_dot(dir, simd_normalize(n.pts[1] - n.pts[0])) + 1.2) * n.weight)
        }
        var r = Double.random(in: 0..<scored.reduce(0) { $0 + $1.1 })
        for (i, w) in scored {
            r -= w
            if r <= 0 { return i }
        }
        return scored.last?.0
    }
}

/// Generic movers on a lane network near the camera: people on footpaths, trams on tracks,
/// boats and ducks on the Main. Each kind gets its own GeoJSON source and model layer.
@MainActor
final class AgentSim {
    struct Kind {
        var weight: Double
        /// Model sections from front to back: model id, distance behind the front, turned 180°.
        var sections: [(model: String, back: Double, flipped: Bool)]
        var length: Double
        var offset: ClosedRange<Double>
        var speed: ClosedRange<Double>
    }

    struct Config {
        var resource: String
        var sourceID: String
        var minZoom: Double
        /// Metres of (weighted) lane per agent, and the cap.
        var spacing: Double
        var maxAgents: Int
        var kinds: [Kind]
        var dwell: Double = 0
        var density: () -> Double = { 1 }
    }

    private struct Agent {
        var lane: Int, prev: Int?, next: Int?
        var d: Double
        var speed: Double, cruise: Double
        var kind: Int
        var offset: Double
        var dwell: Double = 0
        var id: Int
    }

    let config: Config
    private let net: LaneNetwork
    private var agents: [Agent] = []
    private var nextID = 0
    private var sinceManage = 10.0
    private var area = (minX: 0.0, minY: 0.0, maxX: 0.0, maxY: 0.0)
    private var showing = false

    init(_ config: Config) {
        self.config = config
        net = LaneNetwork(resource: config.resource)
    }

    func tick(_ dt: Double, map: MapboxMap) {
        guard !net.lanes.isEmpty else { return }
        guard map.cameraState.zoom >= config.minZoom else {
            if showing { publish(map: map, []); showing = false; agents.removeAll() }
            return
        }
        sinceManage += dt
        if sinceManage > 1 { sinceManage = 0; manage(map) }
        step(dt)
        publish(map: map, agents)
        showing = true
    }

    private func manage(_ map: MapboxMap) {
        let b = map.coordinateBounds(for: CameraOptions(cameraState: map.cameraState))
        let sw = net.local(b.southwest), ne = net.local(b.northeast)
        area = (sw.x - 80, sw.y - 80, ne.x + 80, ne.y + 80)
        agents.removeAll { a in
            let p = net.sample(a.lane, a.d, offset: 0).p
            return p.x < area.minX - 60 || p.x > area.maxX + 60 || p.y < area.minY - 60 || p.y > area.maxY + 60
        }
        let visible = net.lanes.indices.filter { i in
            let l = net.lanes[i]
            return l.maxX >= area.minX && l.minX <= area.maxX && l.maxY >= area.minY && l.minY <= area.maxY
        }
        guard !visible.isEmpty else { return }
        let weights = visible.map { net.lanes[$0].weight * net.lanes[$0].length }
        let total = weights.reduce(0, +)
        let target = min(config.maxAgents, Int(total / config.spacing * config.density()))
        var tries = 0
        while agents.count < target && tries < 200 {
            tries += 1
            var r = Double.random(in: 0..<total)
            var pick = visible[0]
            for (k, w) in weights.enumerated() {
                r -= w
                if r <= 0 { pick = visible[k]; break }
            }
            spawn(on: pick)
        }
    }

    private func pickKind() -> Int {
        var r = Double.random(in: 0..<config.kinds.reduce(0) { $0 + $1.weight })
        for (i, k) in config.kinds.enumerated() {
            r -= k.weight
            if r <= 0 { return i }
        }
        return 0
    }

    private func spawn(on lane: Int) {
        let l = net.lanes[lane]
        let k = pickKind()
        let kind = config.kinds[k]
        guard l.length > kind.length + 2 else { return }
        let d = Double.random(in: kind.length...(l.length - 1))
        if agents.contains(where: { $0.lane == lane && abs($0.d - d) < kind.length + 3 }) { return }
        let cruise = l.speed * Double.random(in: kind.speed)
        agents.append(Agent(lane: lane, prev: nil, next: net.next(after: lane), d: d, speed: cruise, cruise: cruise,
                            kind: k, offset: Double.random(in: kind.offset), id: nextID))
        nextID += 1
    }

    private func step(_ dt: Double) {
        guard dt > 0 else { return }
        var byLane: [Int: [Int]] = [:]
        for (i, a) in agents.enumerated() { byLane[a.lane, default: []].append(i) }
        var gone = Set<Int>()
        for i in agents.indices {
            var a = agents[i]
            if a.dwell > 0 {
                a.dwell -= dt
                agents[i] = a
                continue
            }
            let l = net.lanes[a.lane]
            let len = config.kinds[a.kind].length
            var gap = Double.infinity
            for j in byLane[a.lane] ?? [] where j != i && agents[j].d > a.d && abs(agents[j].offset - a.offset) < 1.5 {
                gap = min(gap, agents[j].d - a.d - (len + config.kinds[agents[j].kind].length) / 2)
            }
            if config.dwell > 0, l.stop { gap = min(gap, l.length - a.d) }
            let target = gap.isFinite ? min(a.cruise, sqrt(max(0, 2 * 2.5 * max(0, gap - 0.8)))) : a.cruise
            a.speed += (target - a.speed) * min(1, dt * 2)
            a.d += a.speed * dt
            if config.dwell > 0, l.stop, a.d >= l.length - 0.5, a.speed < 0.6 {
                a.dwell = config.dwell * Double.random(in: 0.8...1.3)
                a.d = l.length + 0.01
            }
            while a.d > net.lanes[a.lane].length {
                a.d -= net.lanes[a.lane].length
                guard let n = a.next else { gone.insert(a.id); break }
                a.prev = a.lane
                a.lane = n
                a.next = net.next(after: n)
                a.cruise = net.lanes[n].speed * Double.random(in: config.kinds[a.kind].speed)
            }
            agents[i] = a
        }
        if !gone.isEmpty { agents.removeAll { gone.contains($0.id) } }
    }

    private func publish(map: MapboxMap, _ list: [Agent]) {
        var features: [Feature] = []
        features.reserveCapacity(list.count * 2)
        for a in list {
            for s in config.kinds[a.kind].sections {
                var lane = a.lane, d = a.d - s.back
                if d < 0, let p = a.prev { lane = p; d += net.lanes[p].length }
                let (pt, h) = net.sample(lane, d, offset: a.offset)
                var f = Feature(geometry: .point(Point(net.coordinate(pt))))
                f.properties = ["m": .string(s.model), "r": .array([.number(0), .number(0), .number(-(h + (s.flipped ? 180 : 0)))])]
                features.append(f)
            }
        }
        map.updateGeoJSONSource(withId: config.sourceID, geoJSON: .featureCollection(FeatureCollection(features: features)))
    }
}

/// Runs the people, tram and river simulations off one display link.
@MainActor
final class LivingCity: NSObject {
    static let shared = LivingCity()

    private static func person(_ colour: String) -> AgentSim.Kind {
        .init(weight: 1, sections: [("person_\(colour)", 0, false)], length: 0.8, offset: -1.4...1.4, speed: 0.75...1.15)
    }

    /// Busier at lunch and in the evening, quiet at night.
    private static func footfall() -> Double {
        let hour = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "Europe/Berlin")!, from: Date()).hour ?? 12
        switch hour {
        case 0..<6: return 0.2
        case 6..<10: return 0.8
        case 11..<14: return 1.5
        case 17..<21: return 1.4
        case 22...23: return 0.5
        default: return 1
        }
    }

    let people = AgentSim(.init(
        resource: "frankfurt_walks", sourceID: "people", minZoom: 16, spacing: 55, maxAgents: 220,
        kinds: ["red", "blue", "mustard", "green", "white", "lilac"].map(person),
        density: footfall))

    let trams = AgentSim(.init(
        resource: "frankfurt_trams", sourceID: "trams", minZoom: 15, spacing: 650, maxAgents: 14,
        kinds: [.init(weight: 1, sections: [("tram_cab", 0, false), ("tram_mid", 10.2, false), ("tram_cab", 20.4, true)],
                      length: 31, offset: 0...0, speed: 0.8...1)],
        dwell: 12))

    let river = AgentSim(.init(
        resource: "frankfurt_river", sourceID: "river", minZoom: 14.5, spacing: 160, maxAgents: 24,
        kinds: [
            .init(weight: 1, sections: [("boat_excursion", 0, false)], length: 32, offset: 18...32, speed: 0.9...1.1),
            .init(weight: 2, sections: [("boat_rowing", 0, false)], length: 6, offset: 35...55, speed: 0.6...0.9),
            .init(weight: 4, sections: [("duck", 0, false)], length: 0.6, offset: 52...68, speed: 0.08...0.18),
        ]))

    private weak var map: MapboxMap?
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0

    func start(map: MapboxMap?) {
        self.map = map
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        let dt = last == 0 ? 0 : min(link.timestamp - last, 0.1)
        last = link.timestamp
        guard let map else { return }
        people.tick(dt, map: map)
        trams.tick(dt, map: map)
        river.tick(dt, map: map)
        SmallTouches.shared.tick(dt, map: map)
    }
}
