import SharedKit
import SpriteKit
import SupabaseKit
import SwiftUI

/// The LimeZu office: a SpriteKit scene for the art, SwiftUI buttons on top for taps and VoiceOver.
struct SpriteOfficeView: View {
	let art: OfficeArt
	let seats: [DeskSnapshot?]
	let onTapSeat: (Int) -> Void

	@Environment(\.displayScale) private var displayScale
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.scenePhase) private var scenePhase
	@State private var holder = SceneHolder()

	var body: some View {
		let size = art.manifest.scene
		GeometryReader { geo in
			let unit = crispPointsPerPixel(fitting: geo.size.width, artWidth: size.w, displayScale: displayScale)
			let scene = holder.scene(art: art, reduceMotion: reduceMotion)
			ZStack(alignment: .topLeading) {
				SpriteView(
					scene: scene,
					isPaused: scenePhase != .active,
					preferredFramesPerSecond: 30,
					options: [.ignoresSiblingOrder]
				)
				.frame(width: unit * CGFloat(size.w), height: unit * CGFloat(size.h))
				.accessibilityHidden(true)

				ForEach(art.manifest.stations, id: \.seat) { station in
					let tap = station.tap
					Button {
						onTapSeat(station.seat)
					} label: {
						Color.clear.contentShape(Rectangle())
					}
					.buttonStyle(.plain)
					.frame(width: unit * CGFloat(tap.w), height: unit * CGFloat(tap.h))
					.offset(x: unit * CGFloat(tap.x), y: unit * CGFloat(tap.y))
					.accessibilityLabel(seatAccessibilityLabel(station.seat < seats.count ? seats[station.seat] : nil))
					.accessibilityAddTraits(.isButton)
				}
			}
			.frame(width: unit * CGFloat(size.w), height: unit * CGFloat(size.h))
			.frame(maxWidth: .infinity)
			.onAppear { scene.apply(seats: seats) }
			.onChange(of: seats) { _, newSeats in scene.apply(seats: newSeats) }
			.onChange(of: reduceMotion) { _, _ in scene.apply(seats: seats) }
		}
		.aspectRatio(CGFloat(size.w) / CGFloat(size.h), contentMode: .fit)
	}
}

/// Keeps one scene alive across SwiftUI view updates.
private final class SceneHolder {
	private var made: (scene: OfficeScene, reduceMotion: Bool)?

	func scene(art: OfficeArt, reduceMotion: Bool) -> OfficeScene {
		if let made, made.reduceMotion == reduceMotion { return made.scene }
		let scene = OfficeScene(art: art, reduceMotion: reduceMotion)
		made = (scene, reduceMotion)
		return scene
	}
}

struct SpritePortraitView: View {
	let art: OfficeArt
	let look: Look
	var activity: DeskActivity = .idle
	var hasLine = true
	var background: Color = Theme.carpet

	@Environment(\.displayScale) private var displayScale

	var body: some View {
		GeometryReader { geo in
			let side = min(geo.size.width, geo.size.height)
			let unit = crispPointsPerPixel(fitting: side, artWidth: 20, displayScale: displayScale)
			PixelClock { frame, date in
				let time = frame == 0 ? 0 : date.timeIntervalSinceReferenceDate
				if let image = art.portrait(look: look, activity: activity, hasLine: hasLine, time: time) {
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

/// Look editor rows for the LimeZu character layers. Each option shows the deskmate wearing it.
struct SpriteLookRows: View {
	let art: OfficeArt
	@Binding var look: Look

	var body: some View {
		VStack(spacing: 14) {
			OptionRow(title: "Skin", count: art.skinCount, selection: $look.skin, art: art) { look.with(\.skin, $0) }
			OptionRow(title: "Eyes", count: art.eyesCount, selection: $look.eyes, art: art) { look.with(\.eyes, $0) }
			OptionRow(title: "Hair", count: art.hairStyleCount, selection: $look.hair, art: art) {
				look.with(\.hair, $0)
			}
			OptionRow(
				title: "Hair color", count: art.hairColorCount(style: look.hair), selection: $look.hairColor, art: art
			) { look.with(\.hairColor, $0) }
			OptionRow(title: "Outfit", count: art.outfitCount, selection: $look.shirt, art: art) {
				look.with(\.shirt, $0)
			}
			OptionRow(
				title: "Outfit color", count: art.outfitColorCount(style: look.shirt), selection: $look.shirtColor,
				art: art
			) { look.with(\.shirtColor, $0) }
			OptionRow(
				title: "Extras", count: art.accessoryLabels.count, selection: $look.accessory, art: art,
				labels: art.accessoryLabels
			) { look.with(\.accessory, $0) }
		}
	}
}

private struct OptionRow: View {
	let title: String
	let count: Int
	@Binding var selection: Int
	let art: OfficeArt
	var labels: [String] = []
	let preview: (Int) -> Look

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title).font(.rounded(.footnote, weight: .medium)).foregroundStyle(.secondary)
			ScrollViewReader { proxy in
				ScrollView(.horizontal, showsIndicators: false) {
					LazyHStack(spacing: 8) {
						ForEach(0..<max(count, 1), id: \.self) { index in
							let selected = count > 0 && ((selection % count) + count) % count == index
							Button {
								Haptics.impact(style: .light)
								selection = index
							} label: {
								thumbnail(index)
									.frame(width: 44, height: 60)
									.background(Theme.carpet, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
									.overlay {
										RoundedRectangle(cornerRadius: 10, style: .continuous)
											.strokeBorder(Theme.coral, lineWidth: selected ? 2.5 : 0)
									}
							}
							.buttonStyle(.plain)
							.id(index)
							.accessibilityLabel(index < labels.count ? labels[index] : "\(title) \(index + 1)")
							.accessibilityAddTraits(selected ? .isSelected : [])
						}
					}
					.padding(4)
				}
				.onAppear {
					guard count > 0 else { return }
					proxy.scrollTo(((selection % count) + count) % count, anchor: .center)
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	@ViewBuilder
	private func thumbnail(_ index: Int) -> some View {
		if index == 0, !labels.isEmpty {
			Image(systemName: "nosign")
				.font(.system(size: 18, weight: .semibold))
				.foregroundStyle(Theme.paper.opacity(0.7))
		} else if let image = art.thumbnail(preview(index)) {
			Image(decorative: image, scale: 1)
				.interpolation(.none)
				.resizable()
				.frame(width: 32, height: 44)
		}
	}
}

extension Look {
	fileprivate func with(_ key: WritableKeyPath<Look, Int>, _ value: Int) -> Look {
		var copy = self
		copy[keyPath: key] = value
		return copy
	}
}
