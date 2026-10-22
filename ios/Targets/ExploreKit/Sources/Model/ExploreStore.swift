import Foundation
import Observation
import SwiftUI

enum MapMood: String, CaseIterable, Identifiable {
    case day, dawn, dusk, night
    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .day: "sun.max.fill"
        case .dawn: "sunrise.fill"
        case .dusk: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }
}

enum Filter: Hashable, Identifiable {
    case saved, events, category(PlaceCategory)

    var id: String {
        switch self {
        case .saved: "saved"
        case .events: "events"
        case .category(let c): c.rawValue
        }
    }

    var title: String {
        switch self {
        case .saved: "Saved"
        case .events: "This week"
        case .category(let c): c.title
        }
    }

    var symbol: String {
        switch self {
        case .saved: "bookmark.fill"
        case .events: "calendar"
        case .category(let c): c.symbol
        }
    }

    var tint: Color {
        switch self {
        case .saved: Palette.pink
        case .events: Palette.blue
        case .category(let c): c.tint
        }
    }

    static let all: [Filter] = [.saved, .events] + PlaceCategory.allCases.map { .category($0) }
}

@MainActor
@Observable
final class ExploreStore {
    var places: [Place]
    var events: [CityEvent]
    var query = ""
    var filter: Filter?
    var selection: Selection?
    /// `nil` follows the real Frankfurt time of day (`LiveConditions`).
    var manualMood: MapMood?
    var mood: MapMood { manualMood ?? LiveConditions.shared.mood }
    var palette = CityPalette.named(UserDefaults.standard.string(forKey: "palette")) ?? .mayfair {
        didSet { UserDefaults.standard.set(palette.id, forKey: "palette") }
    }
    var is3D = true
    var showsUserLocation = false
    var plannedEventIDs: Set<String> = []

    init(places: [Place] = SeedData.places, events: [CityEvent] = SeedData.events()) {
        self.places = places
        self.events = events
    }

    var savedPlaces: [Place] {
        places.filter(\.isSaved).sorted { ($0.savedFrom?.savedDaysAgo ?? 0) < ($1.savedFrom?.savedDaysAgo ?? 0) }
    }

    var upcomingEvents: [CityEvent] { events.sorted { $0.start < $1.start } }

    var visiblePlaces: [Place] {
        switch filter {
        case .none: places.filter { $0.isSaved || $0.category == .sight }
        case .saved: savedPlaces
        case .events: []
        case .category(let c): places.filter { $0.category == c }
        }
    }

    var visibleEvents: [CityEvent] {
        switch filter {
        case .none, .events: upcomingEvents
        default: []
        }
    }

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var searchPlaces: [Place] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return places.filter { p in
            p.name.lowercased().contains(q) || p.neighbourhood.lowercased().contains(q)
                || p.category.title.lowercased().contains(q) || p.tags.contains { $0.lowercased().contains(q) }
        }
    }

    var searchEvents: [CityEvent] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return upcomingEvents.filter {
            $0.title.lowercased().contains(q) || $0.venue.lowercased().contains(q) || $0.kind.lowercased().contains(q)
        }
    }

    var selectedPlace: Place? {
        if case .place(let id) = selection { return places.first { $0.id == id } }
        return nil
    }

    var selectedEvent: CityEvent? {
        if case .event(let id) = selection { return events.first { $0.id == id } }
        return nil
    }

    func toggleSaved(_ place: Place) {
        guard let i = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[i].savedFrom = places[i].isSaved ? nil : SavedFrom(source: .search, caption: "Saved in Spots", savedDaysAgo: 0)
    }

    func togglePlanned(_ event: CityEvent) {
        if plannedEventIDs.contains(event.id) { plannedEventIDs.remove(event.id) } else { plannedEventIDs.insert(event.id) }
    }
}
