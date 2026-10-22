import MapboxMaps
import simd
import UIKit

/// Pigeons on the Römerberg that scatter when tapped, sparkling fountains, and the odd plane
/// heading for Frankfurt airport.
@MainActor
final class SmallTouches {
    static let shared = SmallTouches()

    static let pigeonSource = "pigeons", pigeonLayer = "pigeons"
    static let sparkleA = "fountain-sparkle-a", sparkleB = "fountain-sparkle-b"
    static let planeSource = "plane", planeLayer = "plane"

    private let flockCentre = CLLocationCoordinate2D(latitude: 50.11047, longitude: 8.68215)
    private let mLat = 111_320.0
    private var mLon: Double { 111_320.0 * cos(50.11 * .pi / 180) }

    // MARK: Pigeons

    private struct Pigeon { var home: SIMD2<Double>; var p: SIMD2<Double>; var heading: Double; var away: SIMD2<Double> }
    private var flock: [Pigeon] = (0..<18).map { _ in
        let a = Double.random(in: 0..<(2 * .pi)), r = Double.random(in: 1...9)
        let p = SIMD2(cos(a) * r, sin(a) * r)
        let dir = SIMD2(cos(a), sin(a))
        return Pigeon(home: p, p: p, heading: Double.random(in: 0..<360), away: dir * Double.random(in: 25...45))
    }
    /// 0 = on the ground; counts up while scattering, then the flock comes back.
    private var scatter: Double = -1
    private var peck: Double = 0

    func tap(at c: CLLocationCoordinate2D) -> Bool {
        let d = SIMD2((c.longitude - flockCentre.longitude) * mLon, (c.latitude - flockCentre.latitude) * mLat)
        guard scatter < 0, simd_length(d) < 40 else { return false }
        scatter = 0
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        return true
    }

    // MARK: Plane

    private var planeClock: Double = 40
    private let planeEvery: Double = 110, planeDuration: Double = 70

    // MARK: Loop

    private var clock: Double = 0
    private var published = false

    func tick(_ dt: Double, map: MapboxMap) {
        clock += dt
        let zoom = map.cameraState.zoom

        // Pigeons peck around; when scattered they fly out and up, vanish, and return 25 s later.
        if zoom >= 16 {
            peck += dt
            var z = 0.0, opacity = 1.0
            if scatter >= 0 {
                scatter += dt
                let t = min(scatter / 1.6, 1)
                z = 30 * t * t
                opacity = 1 - t
                for i in flock.indices { flock[i].p = flock[i].home + flock[i].away * t }
                if scatter > 25 {
                    scatter = -1
                    for i in flock.indices { flock[i].p = flock[i].home }
                    opacity = 1; z = 0
                }
            } else if peck > 0.45 {
                peck = 0
                for i in flock.indices where Bool.random() {
                    flock[i].heading += Double.random(in: -50...50)
                    let step = SIMD2(cos(flock[i].heading * .pi / 180), sin(flock[i].heading * .pi / 180)) * 0.25
                    let next = flock[i].p + step
                    if simd_length(next) < 11 { flock[i].p = next }
                }
            }
            let features = flock.map { b -> Feature in
                var f = Feature(geometry: .point(Point(CLLocationCoordinate2D(
                    latitude: flockCentre.latitude + b.p.y / mLat, longitude: flockCentre.longitude + b.p.x / mLon))))
                f.properties = ["r": .array([.number(0), .number(0), .number(-b.heading)])]
                return f
            }
            map.updateGeoJSONSource(withId: Self.pigeonSource, geoJSON: .featureCollection(FeatureCollection(features: features)))
            try? map.setLayerProperty(for: Self.pigeonLayer, property: "model-translation", value: [0, 0, z])
            try? map.setLayerProperty(for: Self.pigeonLayer, property: "model-opacity", value: opacity)
            published = true
        }

        // Fountains shimmer: two droplet rings fading in and out of step.
        let s = 0.5 + 0.5 * sin(clock * 3.2)
        try? map.setLayerProperty(for: Self.sparkleA, property: "circle-opacity", value: 0.25 + 0.6 * s)
        try? map.setLayerProperty(for: Self.sparkleB, property: "circle-opacity", value: 0.25 + 0.6 * (1 - s))

        // A plane on approach to FRA crosses the city every couple of minutes.
        planeClock += dt
        let phase = planeClock.truncatingRemainder(dividingBy: planeEvery)
        var planes: [Feature] = []
        if phase < planeDuration {
            let start = SIMD2(4200.0, 2600.0), end = SIMD2(-4200.0, -2600.0)   // NE -> SW, towards the airport
            let p = start + (end - start) * (phase / planeDuration)
            let h = atan2(end.y - start.y, end.x - start.x) * 180 / .pi
            var f = Feature(geometry: .point(Point(CLLocationCoordinate2D(
                latitude: 50.112 + p.y / mLat, longitude: 8.68 + p.x / mLon))))
            f.properties = ["r": .array([.number(0), .number(0), .number(-h)])]
            planes.append(f)
        }
        map.updateGeoJSONSource(withId: Self.planeSource, geoJSON: .featureCollection(FeatureCollection(features: planes)))
    }

    /// Droplet points in a ring around every fountain, alternating between the two sparkle layers.
    static let sparkles: (a: FeatureCollection, b: FeatureCollection) = {
        guard let url = exploreBundle.url(forResource: "frankfurt_fountains", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let fc = try? JSONDecoder().decode(FeatureCollection.self, from: data) else { return (.init(features: []), .init(features: [])) }
        var a: [Feature] = [], b: [Feature] = []
        let mLat = 111_320.0, mLon = 111_320.0 * cos(50.11 * .pi / 180)
        for f in fc.features {
            guard case .point(let pt) = f.geometry else { continue }
            for i in 0..<10 {
                let ang = Double(i) / 10 * 2 * .pi, r = i % 2 == 0 ? 2.2 : 1.2
                let c = CLLocationCoordinate2D(latitude: pt.coordinates.latitude + sin(ang) * r / mLat,
                                               longitude: pt.coordinates.longitude + cos(ang) * r / mLon)
                let drop = Feature(geometry: .point(Point(c)))
                if i % 2 == 0 { a.append(drop) } else { b.append(drop) }
            }
        }
        return (.init(features: a), .init(features: b))
    }()
}

/// Map layers for people, trams, river life, pigeons, fountains and the plane.
struct LivingLayers: MapStyleContent {
    private static func toy(_ z15: Double, _ z18: Double) -> Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            15
            [z15, z15, z15]
            18
            [z18, z18, z18]
        }
    }

    private static func empty() -> GeoJSONSourceData { .featureCollection(FeatureCollection(features: [])) }

    private static var droplet: Exp {
        Exp(.interpolate) {
            Exp(.exponential) { 2 }
            Exp(.zoom)
            15
            0.6
            20
            19
        }
    }

    var body: some MapStyleContent {
        GeoJSONSource(id: "people").data(Self.empty())
        GeoJSONSource(id: "trams").data(Self.empty())
        GeoJSONSource(id: "river").data(Self.empty())
        GeoJSONSource(id: SmallTouches.pigeonSource).data(Self.empty())
        GeoJSONSource(id: SmallTouches.planeSource).data(Self.empty())
        GeoJSONSource(id: "fountain-a").data(.featureCollection(SmallTouches.sparkles.a))
        GeoJSONSource(id: "fountain-b").data(.featureCollection(SmallTouches.sparkles.b))

        Model(id: "person_red", uri: PuffyTrees.model("person_red"))
        Model(id: "person_blue", uri: PuffyTrees.model("person_blue"))
        Model(id: "person_mustard", uri: PuffyTrees.model("person_mustard"))
        Model(id: "person_green", uri: PuffyTrees.model("person_green"))
        Model(id: "person_white", uri: PuffyTrees.model("person_white"))
        Model(id: "person_lilac", uri: PuffyTrees.model("person_lilac"))
        Model(id: "tram_cab", uri: PuffyTrees.model("tram_cab"))
        Model(id: "tram_mid", uri: PuffyTrees.model("tram_mid"))
        Model(id: "boat_excursion", uri: PuffyTrees.model("boat_excursion"))
        Model(id: "boat_rowing", uri: PuffyTrees.model("boat_rowing"))
        Model(id: "duck", uri: PuffyTrees.model("duck"))
        Model(id: "pigeon", uri: PuffyTrees.model("pigeon"))
        Model(id: "plane", uri: PuffyTrees.model("plane"))

        ModelLayer(id: "people", source: "people")
            .slot(.middle).minZoom(16)
            .modelId(Exp(.get) { "m" }).modelType(.common3d)
            .modelScale(Self.toy(1.9, 1.5)).modelRotation(Exp(.get) { "r" })
            .modelCastShadows(true).modelReceiveShadows(true)

        ModelLayer(id: "trams", source: "trams")
            .slot(.middle).minZoom(15)
            .modelId(Exp(.get) { "m" }).modelType(.common3d)
            .modelScale(Self.toy(1.15, 1.0)).modelRotation(Exp(.get) { "r" })
            .modelCastShadows(true).modelReceiveShadows(true)

        ModelLayer(id: "river", source: "river")
            .slot(.middle).minZoom(14.5)
            .modelId(Exp(.get) { "m" }).modelType(.common3d)
            .modelScale(Exp(.match) {
                Exp(.get) { "m" }
                "duck"
                Self.toy(5, 3.5)
                Self.toy(1.2, 1.0)
            })
            .modelRotation(Exp(.get) { "r" })
            .modelCastShadows(true)

        ModelLayer(id: SmallTouches.pigeonLayer, source: SmallTouches.pigeonSource)
            .slot(.middle).minZoom(16)
            .modelId("pigeon").modelType(.common3d)
            .modelScale(Self.toy(4, 3)).modelRotation(Exp(.get) { "r" })
            .modelCastShadows(true)

        ModelLayer(id: SmallTouches.planeLayer, source: SmallTouches.planeSource)
            .slot(.middle).minZoom(12)
            .modelId("plane").modelType(.common3d)
            .modelScale(Exp(.literal) { [2.5, 2.5, 2.5] }).modelRotation(Exp(.get) { "r" })
            .modelTranslation(Exp(.literal) { [0.0, 0.0, 260.0] })
            .modelCastShadows(false)

        CircleLayer(id: SmallTouches.sparkleA, source: "fountain-a")
            .slot(.middle).minZoom(16)
            .circlePitchAlignment(.map).circleColor(StyleColor(UIColor(red: 0.85, green: 0.95, blue: 1, alpha: 1)))
            .circleRadius(Self.droplet).circleBlur(0.4).circleEmissiveStrength(1)
        CircleLayer(id: SmallTouches.sparkleB, source: "fountain-b")
            .slot(.middle).minZoom(16)
            .circlePitchAlignment(.map).circleColor(StyleColor(UIColor(red: 0.85, green: 0.95, blue: 1, alpha: 1)))
            .circleRadius(Self.droplet).circleBlur(0.4).circleEmissiveStrength(1)
    }
}
