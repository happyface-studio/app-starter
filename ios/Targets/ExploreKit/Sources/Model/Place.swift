import CoreLocation
import SwiftUI

public enum PlaceCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case food, cafe, bar, sight, park

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .food: "Food"
        case .cafe: "Cafés"
        case .bar: "Bars"
        case .sight: "Sights"
        case .park: "Parks"
        }
    }

    var singular: String {
        switch self {
        case .food: "Food"
        case .cafe: "Café"
        case .bar: "Bar"
        case .sight: "Sight"
        case .park: "Park"
        }
    }

    var symbol: String {
        switch self {
        case .food: "fork.knife"
        case .cafe: "cup.and.saucer.fill"
        case .bar: "wineglass.fill"
        case .sight: "star.fill"
        case .park: "leaf.fill"
        }
    }

    var tint: Color {
        switch self {
        case .food: Palette.orange
        case .cafe: Palette.brown
        case .bar: Palette.purple
        case .sight: Palette.indigo
        case .park: Palette.green
        }
    }
}

public enum SaveSource: String, Codable, Sendable {
    case tiktok, instagram, search

    var label: String {
        switch self {
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .search: "Search"
        }
    }

    var symbol: String {
        switch self {
        case .tiktok: "music.note"
        case .instagram: "camera"
        case .search: "magnifyingglass"
        }
    }

    var tint: Color {
        switch self {
        case .tiktok: .black
        case .instagram: Color(red: 0.86, green: 0.19, blue: 0.47)
        case .search: .secondary
        }
    }
}

public struct SavedFrom: Hashable, Codable, Sendable {
    var source: SaveSource
    var caption: String
    var savedDaysAgo: Int
}

public struct Place: Identifiable, Hashable, Sendable {
    public let id: String
    var name: String
    var category: PlaceCategory
    var neighbourhood: String
    var address: String
    var blurb: String
    var tags: [String]
    var priceLevel: Int?
    var latitude: Double
    var longitude: Double
    var savedFrom: SavedFrom?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isSaved: Bool { savedFrom != nil }

    var subtitle: String {
        var parts = [category.singular, neighbourhood]
        if let priceLevel { parts.append(String(repeating: "€", count: priceLevel)) }
        return parts.joined(separator: " · ")
    }
}

public struct CityEvent: Identifiable, Hashable, Sendable {
    public let id: String
    var title: String
    var venue: String
    var kind: String
    var symbol: String
    var tint: Color
    var start: Date
    var durationHours: Double
    var price: String
    var blurb: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum Selection: Hashable {
    case place(String)
    case event(String)
}

enum Palette {
    static let orange = Color(red: 0.95, green: 0.55, blue: 0.24)
    static let brown = Color(red: 0.72, green: 0.47, blue: 0.30)
    static let purple = Color(red: 0.62, green: 0.45, blue: 0.86)
    static let indigo = Color(red: 0.49, green: 0.47, blue: 0.86)
    static let green = Color(red: 0.36, green: 0.66, blue: 0.33)
    static let pink = Color(red: 0.93, green: 0.36, blue: 0.52)
    static let blue = Color(red: 0.25, green: 0.56, blue: 0.93)
    static let ink = Color(red: 0.18, green: 0.20, blue: 0.33)
}
