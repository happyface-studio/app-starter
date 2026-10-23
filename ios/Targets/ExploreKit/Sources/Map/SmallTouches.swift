import MapboxMaps
import simd
import UIKit

/// Sparkling fountains and the odd plane heading for Frankfurt airport.
@MainActor
final class SmallTouches {
    static let shared = SmallTouches()

    static let sparkleA = "fountain-sparkle-a", sparkleB = "fountain-sparkle-b"
    static let planeSource = "plane", planeLayer = "plane"

    private let mLat = 111_320.0
    private var mLon: Double { 111_320.0 * cos(50.11 * .pi / 180) }

    // MARK: Plane

    private var planeClock: Double = 40
    private let planeEvery: Double = 110, planeDuration: Double = 70

    // MARK: Loop

    private var clock: Double = 0
    private var sinceSparkle: Double = 0
    private let planeLive = LiveSource(SmallTouches.planeSource, rate: 15, movingRate: 8)

    func styleLoaded() { planeLive.reset() }

    func tick(_ dt: Double, map: MapboxMap) {
        clock += dt

        // Fountains shimmer: two droplet rings fading in and out of step.
        sinceSparkle += dt
        if sinceSparkle > 0.1, map.cameraState.zoom >= 16 {
            sinceSparkle = 0
            let s = 0.5 + 0.5 * sin(clock * 3.2)
            try? map.setLayerProperty(for: Self.sparkleA, property: "circle-opacity", value: 0.25 + 0.6 * s)
            try? map.setLayerProperty(for: Self.sparkleB, property: "circle-opacity", value: 0.25 + 0.6 * (1 - s))
        }

        // A plane on approach to FRA crosses the city every couple of minutes.
        planeClock += dt
        let phase = planeClock.truncatingRemainder(dividingBy: planeEvery)
        guard planeLive.due(map) else { return }
        var planes: [Feature] = []
        if phase < planeDuration {
            let start = SIMD2(4200.0, 2600.0), end = SIMD2(-4200.0, -2600.0)   // NE -> SW, towards the airport
            let p = start + (end - start) * (phase / planeDuration)
            let h = atan2(end.y - start.y, end.x - start.x) * 180 / .pi
            var f = Feature(geometry: .point(Point(CLLocationCoordinate2D(
                latitude: 50.112 + p.y / mLat, longitude: 8.68 + p.x / mLon))))
            f.identifier = .string("plane")
            f.properties = ["r": .array([.number(0), .number(0), .number(-h)])]
            planes.append(f)
        }
        planeLive.publish(planes, map: map)
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

/// Map layers for people, trams, river life, fountains and the plane.
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
        GeoJSONSource.live("people")
        GeoJSONSource.live("trams")
        GeoJSONSource.live("river")
        GeoJSONSource.live(SmallTouches.planeSource)
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
        Model(id: "plane", uri: PuffyTrees.model("plane"))

        ModelLayer(id: "people", source: "people")
            .slot(.middle).minZoom(16)
            .modelId(Exp(.get) { "m" }).modelType(.common3d)
            .modelScale(Self.toy(1.4, 1.05)).modelRotation(Exp(.get) { "r" })
            .modelCastShadows(true).modelReceiveShadows(true)

        ModelLayer(id: "trams", source: "trams")
            .slot(.middle).minZoom(15)
            .modelId(Exp(.get) { "m" }).modelType(.common3d)
            .modelScale(Self.toy(1.15, 1.0)).modelRotation(Exp(.get) { "r" })
            .modelCastShadows(true).modelReceiveShadows(true)

        // Zoom curves must be top-level, so boats and ducks get a layer each instead of a match.
        ModelLayer(id: "river", source: "river")
            .slot(.middle).minZoom(14.5)
            .filter(Exp(.neq) { Exp(.get) { "m" }; "duck" })
            .modelId(Exp(.get) { "m" }).modelType(.common3d)
            .modelScale(Self.toy(1.2, 1.0))
            .modelRotation(Exp(.get) { "r" })
            .modelCastShadows(true)

        ModelLayer(id: "river-ducks", source: "river")
            .slot(.middle).minZoom(15.5)
            .filter(Exp(.eq) { Exp(.get) { "m" }; "duck" })
            .modelId("duck").modelType(.common3d)
            .modelScale(Self.toy(3, 2.2))
            .modelRotation(Exp(.get) { "r" })

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
