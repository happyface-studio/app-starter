import SwiftUI

struct OutlinedText: View {
    var text: String
    var color: Color
    var size: CGFloat = 13

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .shadow(color: .white, radius: 0.6)
            .shadow(color: .white, radius: 0.6)
            .shadow(color: .white.opacity(0.9), radius: 1.6)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 120, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct IconBadge: View {
    var symbol: String
    var tint: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [tint.mix(with: .white, by: 0.18), tint],
                        startPoint: .top, endPoint: .bottom))
            )
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: tint.opacity(0.45), radius: 4, y: 2)
    }
}

struct SpotMarker: View {
    var place: Place
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                IconBadge(symbol: place.category.symbol, tint: place.category.tint, size: isSelected ? 42 : 30)
                if place.isSaved {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(Palette.pink))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .offset(x: 4, y: -4)
                }
            }
            OutlinedText(text: place.name, color: place.category.tint.mix(with: .black, by: 0.25), size: isSelected ? 15 : 13)
        }
        .scaleEffect(isSelected ? 1.05 : 1, anchor: .leading)
        .animation(.spring(duration: 0.35, bounce: 0.4), value: isSelected)
        .contentShape(Rectangle())
    }
}

struct EventMarker: View {
    var event: CityEvent
    var isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            VStack(spacing: 0) {
                Text(event.start.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(event.tint)
                Text(event.start.formatted(.dateTime.day()))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: isSelected ? 44 : 34, height: isSelected ? 46 : 36)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white, lineWidth: 2))
            .shadow(color: event.tint.opacity(0.4), radius: 5, y: 2)
            OutlinedText(text: event.title, color: event.tint.mix(with: .black, by: 0.3), size: 12)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 110)
        }
        .animation(.spring(duration: 0.35, bounce: 0.4), value: isSelected)
        .contentShape(Rectangle())
    }
}
