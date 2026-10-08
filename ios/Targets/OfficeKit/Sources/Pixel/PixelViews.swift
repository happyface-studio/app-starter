import SupabaseKit
import SwiftUI

/// Picks the largest whole number of device pixels per art pixel that fits, so every art pixel
/// is the same size on screen.
private func crispPointsPerPixel(fitting width: CGFloat, artWidth: Int, displayScale: CGFloat) -> CGFloat {
	let devicePixels = max(1, floor(width * displayScale / CGFloat(artWidth)))
	return devicePixels / displayScale
}

/// Drives pixel animation at 8 fps; frozen when Reduce Motion is on.
private struct PixelClock<Content: View>: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@ViewBuilder var content: (_ frame: Int, _ date: Date) -> Content

	var body: some View {
		TimelineView(.periodic(from: .now, by: 1.0 / 8.0)) { context in
			let frame = reduceMotion ? 0 : Int(context.date.timeIntervalSinceReferenceDate * 8)
			content(frame, context.date)
		}
	}
}

struct OfficeSceneView: View {
	let seats: [DeskSnapshot?]
	let onTapSeat: (Int) -> Void

	@Environment(\.displayScale) private var displayScale

	private typealias L = PixelArt.Layout

	var body: some View {
		GeometryReader { geo in
			let unit = crispPointsPerPixel(fitting: geo.size.width, artWidth: L.sceneWidth, displayScale: displayScale)
			let width = unit * CGFloat(L.sceneWidth)
			let height = unit * CGFloat(L.sceneHeight)
			ZStack(alignment: .topLeading) {
				PixelClock { frame, date in
					if let image = OfficeRenderer.office(seats: seats, frame: frame, date: date) {
						Image(decorative: image, scale: 1)
							.interpolation(.none)
							.resizable()
							.frame(width: width, height: height)
					}
				}
				ForEach(0..<seats.count, id: \.self) { seat in
					Button {
						onTapSeat(seat)
					} label: {
						Color.clear.contentShape(Rectangle())
					}
					.buttonStyle(.plain)
					.frame(width: unit * CGFloat(L.cellWidth), height: unit * CGFloat(L.cellHeight))
					.offset(
						x: unit * CGFloat((seat % 2) * L.cellWidth),
						y: unit * CGFloat(L.wallHeight + (seat / 2) * L.cellHeight)
					)
					.accessibilityLabel(accessibilityLabel(for: seat))
					.accessibilityAddTraits(.isButton)
				}
			}
			.frame(width: width, height: height)
			.frame(maxWidth: .infinity)
		}
		.aspectRatio(CGFloat(L.sceneWidth) / CGFloat(L.sceneHeight), contentMode: .fit)
	}

	private func accessibilityLabel(for seat: Int) -> String {
		guard let desk = seats[seat] else { return "Empty desk. Hire a deskmate." }
		let status: String =
			switch desk.activity {
				case .idle: desk.hasLine ? "Waiting for calls" : "No phone yet"
				case .ringing: "Phone ringing"
				case .listening: "On a call, listening"
				case .thinking: "On a call, thinking"
				case .speaking: "On a call, talking"
				case .human: "You're on this call"
			}
		return "\(desk.name)'s desk. \(status)."
	}
}

/// One deskmate on their chair, animated.
struct PortraitView: View {
	let look: Look
	var activity: DeskActivity = .idle
	var background: Color = Theme.carpet

	@Environment(\.displayScale) private var displayScale

	var body: some View {
		GeometryReader { geo in
			let side = min(geo.size.width, geo.size.height)
			let unit = crispPointsPerPixel(fitting: side, artWidth: 20, displayScale: displayScale)
			PixelClock { frame, _ in
				if let image = OfficeRenderer.portrait(look: look, activity: activity, frame: frame) {
					Image(decorative: image, scale: 1)
						.interpolation(.none)
						.resizable()
						.frame(width: unit * 20, height: unit * 20)
				}
			}
			.frame(width: geo.size.width, height: geo.size.height)
		}
		.background(background)
		.accessibilityHidden(true)
	}
}
