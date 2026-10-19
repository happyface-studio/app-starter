import SwiftUI

struct SectionHeader: View {
    var title: String
    var caption: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Spacer()
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct FilterChip: View {
    var filter: Filter
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isOn ? .white : filter.tint)
                Text(filter.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(isOn ? .white : .primary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(Capsule().fill(isOn ? AnyShapeStyle(filter.tint) : AnyShapeStyle(.white.opacity(0.75))))
            .overlay(Capsule().strokeBorder(.black.opacity(isOn ? 0 : 0.06)))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

struct SourcePill: View {
    var saved: SavedFrom

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: saved.source.symbol)
                .font(.system(size: 9, weight: .bold))
            Text(saved.source == .search ? "Saved" : saved.source.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(saved.source == .search ? Color.secondary : .white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(saved.source == .search ? AnyShapeStyle(.quaternary) : AnyShapeStyle(saved.source.tint)))
    }
}

struct PlaceRow: View {
    var place: Place

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: place.category.symbol, tint: place.category.tint, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(place.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let saved = place.savedFrom {
                SourcePill(saved: saved)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct EventCard: View {
    var event: CityEvent
    var isPlanned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [event.tint.mix(with: .white, by: 0.25), event.tint],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: event.symbol)
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white.opacity(0.28))
                    .rotationEffect(.degrees(-10))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 6, y: 8)
                VStack(alignment: .leading, spacing: 0) {
                    Text(event.start.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                    Text(event.start.formatted(.dateTime.day()))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(12)
                if isPlanned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                        .padding(10)
                }
            }
            .frame(height: 92)
            .clipped()

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .lineLimit(2, reservesSpace: true)
                Text("\(event.start.formatted(.dateTime.hour().minute())) · \(event.venue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
        }
        .frame(width: 168)
        .background(.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

struct ActionButton: View {
    var title: String
    var symbol: String
    var tint: Color
    var isProminent = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(isProminent ? .white : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isProminent ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.12)))
            )
        }
        .buttonStyle(.plain)
    }
}

struct CloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.quaternary))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

struct TagFlow: View {
    var tags: [String]
    var tint: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(tint.mix(with: .black, by: 0.25))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(tint.opacity(0.13)))
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
