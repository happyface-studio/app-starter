import SwiftUI

/// The miniature-photo look: the far edge of the city softly blurred and hazed, a lighter blur at
/// the near edge, sharp in the middle where you're looking. Only in 3D, where there's a horizon.
struct TiltShift: View {
    var mood: MapMood

    private var haze: Color {
        switch mood {
        case .night: Color(red: 0.10, green: 0.12, blue: 0.22)
        case .dusk: Color(red: 0.98, green: 0.78, blue: 0.66)
        case .dawn: Color(red: 0.98, green: 0.86, blue: 0.80)
        case .day: Color(red: 0.90, green: 0.93, blue: 0.97)
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    haze.opacity(0.35)
                }
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.7), location: 0.35),
                                             .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .frame(height: geo.size.height * 0.3)
                Spacer(minLength: 0)
                Rectangle().fill(.ultraThinMaterial)
                    .mask(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                    .frame(height: geo.size.height * 0.14)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
