import CoreLocation
import SwiftUI

private func directionsURL(_ c: CLLocationCoordinate2D, name: String) -> URL? {
    var parts = URLComponents(string: "maps://")
    parts?.queryItems = [
        .init(name: "daddr", value: "\(c.latitude),\(c.longitude)"),
        .init(name: "q", value: name),
        .init(name: "dirflg", value: "w"),
    ]
    return parts?.url
}

struct PlaceDetailView: View {
    @Bindable var store: ExploreStore
    var place: Place
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    IconBadge(symbol: place.category.symbol, tint: place.category.tint, size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text(place.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    CloseButton { store.selection = nil }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)

                HStack(spacing: 10) {
                    ActionButton(title: "Directions", symbol: "figure.walk", tint: Palette.blue, isProminent: true) {
                        if let url = directionsURL(place.coordinate, name: place.name) { openURL(url) }
                    }
                    ActionButton(
                        title: place.isSaved ? "Saved" : "Save",
                        symbol: place.isSaved ? "bookmark.fill" : "bookmark",
                        tint: Palette.pink
                    ) {
                        store.toggleSaved(place)
                    }
                    .sensoryFeedback(.success, trigger: place.isSaved)
                    ShareLink(item: "\(place.name), \(place.address), Frankfurt") {
                        VStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .semibold))
                            Text("Share").font(.system(.caption, design: .rounded, weight: .semibold))
                        }
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.ink.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                if let saved = place.savedFrom, saved.source != .search {
                    savedFromCard(saved)
                        .padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.system(.headline, design: .rounded))
                    Text(place.blurb)
                        .font(.body)
                        .foregroundStyle(.primary.opacity(0.85))
                }
                .padding(.horizontal, 20)

                TagFlow(tags: place.tags, tint: place.category.tint)

                Label(place.address + ", Frankfurt am Main", systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private func savedFromCard(_ saved: SavedFrom) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [saved.source.tint, place.category.tint], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "play.fill").foregroundStyle(.white)
            }
            .frame(width: 44, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text("Saved from \(saved.source.label)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text("“\(saved.caption)”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(saved.savedDaysAgo == 0 ? "Today" : "\(saved.savedDaysAgo) days ago")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.7)))
    }
}

struct EventDetailView: View {
    @Bindable var store: ExploreStore
    var event: CityEvent
    @Environment(\.openURL) private var openURL

    private var isPlanned: Bool { store.plannedEventIDs.contains(event.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Text(event.start.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(event.tint)
                        Text(event.start.formatted(.dateTime.day()))
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .frame(maxHeight: .infinity)
                    }
                    .frame(width: 54, height: 58)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: event.tint.opacity(0.3), radius: 5, y: 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text("\(event.kind) · \(event.venue)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    CloseButton { store.selection = nil }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)

                HStack(spacing: 10) {
                    ActionButton(
                        title: isPlanned ? "In your plan" : "Add to plan",
                        symbol: isPlanned ? "checkmark.circle.fill" : "calendar.badge.plus",
                        tint: event.tint, isProminent: true
                    ) {
                        store.togglePlanned(event)
                    }
                    .sensoryFeedback(.success, trigger: isPlanned)
                    ActionButton(title: "Directions", symbol: "figure.walk", tint: Palette.blue) {
                        if let url = directionsURL(event.coordinate, name: event.venue) { openURL(url) }
                    }
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 10) {
                    infoRow("clock", timeRange)
                    infoRow("ticket", event.price)
                    infoRow("mappin.and.ellipse", event.venue)
                }
                .padding(.horizontal, 20)

                Text(event.blurb)
                    .padding(.horizontal, 20)

                Text("Sample event. The city events scraper lands in the next build.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var timeRange: String {
        let end = event.start.addingTimeInterval(event.durationHours * 3600)
        return "\(event.start.formatted(.dateTime.weekday(.wide).day().month())) · \(event.start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }

    private func infoRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundStyle(event.tint)
            Text(text)
                .font(.subheadline)
        }
    }
}
