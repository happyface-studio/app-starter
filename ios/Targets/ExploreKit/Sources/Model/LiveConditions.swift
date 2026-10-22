import Foundation
import Observation

enum Season: String, CaseIterable, Identifiable {
    case spring, summer, autumn, winter

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .spring: "camera.macro"
        case .summer: "sun.max"
        case .autumn: "leaf"
        case .winter: "snowflake"
        }
    }

    /// Model-name suffix for seasonal trees (`tree_a_autumn` etc.); summer uses the plain models.
    var modelSuffix: String { self == .summer ? "" : "_\(rawValue)" }

    static func of(_ date: Date) -> Season {
        switch Calendar(identifier: .gregorian).component(.month, from: date) {
        case 3, 4: .spring
        case 5...9: .summer
        case 10, 11: .autumn
        default: .winter
        }
    }
}

enum Sky: String {
    case clear, partly, cloudy, fog, drizzle, rain, snow, storm

    /// WMO weather interpretation codes, as used by Open-Meteo.
    init(wmo: Int) {
        switch wmo {
        case 0: self = .clear
        case 1, 2: self = .partly
        case 3: self = .cloudy
        case 45, 48: self = .fog
        case 51...57: self = .drizzle
        case 61...67, 80...82: self = .rain
        case 71...77, 85, 86: self = .snow
        case 95...99: self = .storm
        default: self = .partly
        }
    }

    var isWet: Bool { [.drizzle, .rain, .storm].contains(self) }
}

/// The real Frankfurt "now": sun phase from the clock, weather from Open-Meteo (no key needed),
/// season from the date. Launch arguments `-weather rain|snow|…` and `-season autumn|…` override.
@Observable
@MainActor
final class LiveConditions {
    static let shared = LiveConditions()

    private(set) var mood: MapMood = .day
    /// `nil` follows the calendar. Picking winter by hand also snows the city in.
    var manualSeason: Season? = UserDefaults.standard.string(forKey: "season").flatMap(Season.init(rawValue:))
    private var calendarSeason: Season = .of(Date())
    var season: Season { manualSeason ?? calendarSeason }
    private(set) var sky: Sky = .partly
    private(set) var cloudCover: Double = 0.4
    /// Wind the clouds drift with: speed in m/s, direction it blows *towards* in degrees from north.
    private(set) var windSpeed: Double = 3
    private(set) var windTowards: Double = 70
    private(set) var snowDepth: Double = 0

    /// How snowed-in the city looks, 0...1: lying snow from the weather service, or snow falling in winter.
    var snowCover: Double {
        if manualSeason == .winter { return 1 }
        if manualSeason != nil { return 0 }
        if sky == .snow && (season == .winter || snowDepth > 0) { return 1 }
        return min(1, snowDepth / 0.03)
    }

    private let latitude = 50.1109, longitude = 8.6821
    private var timer: Timer?
    private var lastFetch = Date.distantPast
    private let forcedSky = UserDefaults.standard.string(forKey: "weather").flatMap(Sky.init(rawValue:))

    private init() {
        if let forcedSky { apply(sky: forcedSky) }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in LiveConditions.shared.refresh() }
        }
    }

    private func refresh() {
        let now = Date()
        mood = Self.mood(at: now, latitude: latitude, longitude: longitude)
        calendarSeason = .of(now)
        if forcedSky == nil, now.timeIntervalSince(lastFetch) > 15 * 60 {
            lastFetch = now
            Task { await fetchWeather() }
        }
    }

    private func apply(sky: Sky) {
        self.sky = sky
        cloudCover = switch sky {
        case .clear: 0.1
        case .partly: 0.4
        case .cloudy, .fog: 0.9
        default: 1
        }
    }

    private func fetchWeather() async {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            .init(name: "latitude", value: "\(latitude)"), .init(name: "longitude", value: "\(longitude)"),
            .init(name: "current", value: "weather_code,cloud_cover,wind_speed_10m,wind_direction_10m,snow_depth"),
            .init(name: "wind_speed_unit", value: "ms"),
        ]
        guard let url = c.url,
              let (data, _) = try? await URLSession.shared.data(from: url) as (Data, URLResponse),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any] else { return }
        if let code = current["weather_code"] as? Int { apply(sky: Sky(wmo: code)) }
        if let cover = current["cloud_cover"] as? Double { cloudCover = cover / 100 }
        if let speed = current["wind_speed_10m"] as? Double { windSpeed = speed }
        if let depth = current["snow_depth"] as? Double { snowDepth = depth }
        if let from = current["wind_direction_10m"] as? Double { windTowards = (from + 180).truncatingRemainder(dividingBy: 360) }
    }

    /// Solar elevation (NOAA approximation, good to a fraction of a degree) mapped to a light preset.
    static func mood(at date: Date, latitude: Double, longitude: Double) -> MapMood {
        let elevation = solarElevation(at: date, latitude: latitude, longitude: longitude)
        if elevation > 6 { return .day }
        if elevation < -6 { return .night }
        let hour = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "Europe/Berlin")!, from: date).hour ?? 12
        return hour < 12 ? .dawn : .dusk
    }

    static func solarElevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let rad = Double.pi / 180
        let jd = date.timeIntervalSince1970 / 86400 + 2_440_587.5
        let n = jd - 2_451_545.0
        let meanLong = (280.460 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let meanAnom = (357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360) * rad
        let eclLong = (meanLong + 1.915 * sin(meanAnom) + 0.020 * sin(2 * meanAnom)) * rad
        let obliquity = (23.439 - 0.0000004 * n) * rad
        let decl = asin(sin(obliquity) * sin(eclLong))
        let ra = atan2(cos(obliquity) * sin(eclLong), cos(eclLong))
        let gmst = (18.697374558 + 24.06570982441908 * n).truncatingRemainder(dividingBy: 24)
        let hourAngle = (gmst * 15 + longitude) * rad - ra
        let lat = latitude * rad
        return asin(sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(hourAngle)) / rad
    }
}
