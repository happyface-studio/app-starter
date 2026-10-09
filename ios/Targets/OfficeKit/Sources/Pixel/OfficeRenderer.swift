import CoreGraphics
import Foundation
import SupabaseKit

enum DeskActivity: Equatable {
	case idle, ringing, dialing, listening, thinking, speaking, human

	/// Someone is on the line (as opposed to the phone ringing or being dialed).
	var isTalking: Bool {
		switch self {
			case .listening, .thinking, .speaking, .human: true
			case .idle, .ringing, .dialing: false
		}
	}

	init(call: Call?) {
		guard let call, call.isLive else {
			self = .idle
			return
		}
		switch call.status {
			case .ringing: self = .ringing
			case .dialing: self = .dialing
			case .human: self = .human
			default:
				switch call.agentState {
					case "speaking": self = .speaking
					case "thinking": self = .thinking
					default: self = .listening
				}
		}
	}
}

struct DeskSnapshot: Equatable {
	var name: String
	var look: Look
	var hasLine: Bool
	var activity: DeskActivity
}

enum Sky: String {
	case day, dusk, night

	init(date: Date) {
		let hour = Calendar.current.component(.hour, from: date)
		switch hour {
			case 7..<17: self = .day
			case 6, 17..<20: self = .dusk
			default: self = .night
		}
	}
}

/// Draws the office. Mirrors `ios/Tools/pixelart/render.py`, which is the visual reference.
enum OfficeRenderer {
	typealias L = PixelArt.Layout

	static func office(seats: [DeskSnapshot?], frame t: Int, date: Date) -> CGImage? {
		var buf = PixelBuffer(width: L.sceneWidth, height: L.sceneHeight)
		drawWall(&buf, sky: Sky(date: date), frame: t, date: date)
		drawCarpet(&buf)
		for seat in 0..<(L.rows * 2) {
			let ox = (seat % 2) * L.cellWidth
			let oy = L.wallHeight + (seat / 2) * L.cellHeight
			drawCell(&buf, ox, oy, seat < seats.count ? seats[seat] : nil, frame: t)
		}
		return buf.makeImage()
	}

	/// A single deskmate on their chair, for headers and the look editor.
	static func portrait(look: Look, activity: DeskActivity, frame t: Int) -> CGImage? {
		var buf = PixelBuffer(width: 20, height: 20)
		buf.blit(PixelArt.chair, 1, 10, PixelArt.fixed)
		drawCharacter(&buf, look: look, 2, 1, activity: activity, frame: t)
		return buf.makeImage()
	}

	// MARK: - Character

	static func palette(for look: Look) -> Palette {
		var pal = PixelArt.fixed
		let skin = PixelArt.skins[abs(look.skin) % PixelArt.skins.count]
		let hair = PixelArt.hairColors[abs(look.hairColor) % PixelArt.hairColors.count]
		let shirt = PixelArt.shirts[abs(look.shirt) % PixelArt.shirts.count]
		pal["s"] = skin.0
		pal["S"] = skin.1
		pal["h"] = hair.0
		pal["H"] = hair.1
		pal["c"] = shirt.0
		pal["C"] = shirt.1
		return pal
	}

	static func drawCharacter(
		_ buf: inout PixelBuffer, look: Look, _ x: Int, _ y: Int, activity: DeskActivity, frame t: Int
	) {
		let pal = palette(for: look)
		var bob = (t / 8) % 2 == 1 ? 1 : 0
		if activity == .listening, (8...11).contains(t % 16) { bob = 1 }
		let y = y + bob
		buf.blit(PixelArt.body, x, y, pal)
		buf.blit(t % 44 < 2 ? PixelArt.faceBlink : PixelArt.face, x, y, pal)
		if activity == .speaking, (t / 2) % 2 == 0 {
			buf.blit(PixelArt.mouthOpen, x, y, pal)
		}
		buf.blit(PixelArt.hairStyles[abs(look.hair) % PixelArt.hairStyles.count], x, y, pal)
		buf.blit(PixelArt.accessories[abs(look.accessory) % PixelArt.accessories.count], x, y, pal)
	}

	// MARK: - Room

	private static func drawWall(_ buf: inout PixelBuffer, sky: Sky, frame t: Int, date: Date) {
		let k = PixelArt.fixed["k"]!
		let w = PixelArt.fixed["w"]!
		buf.rect(0, 0, L.sceneWidth, L.wallHeight, PixelArt.wall)
		buf.rect(0, L.wallHeight - 5, L.sceneWidth, 3, PixelArt.wallShade)
		buf.rect(0, L.wallHeight - 2, L.sceneWidth, 2, PixelArt.baseboard)
		let (low, high) = PixelArt.sky[sky.rawValue]!
		for wx in [7, 63] {
			buf.rect(wx - 1, 2, 28, 16, k)
			buf.rect(wx, 3, 26, 14, w)
			buf.rect(wx + 1, 4, 24, 12, low)
			buf.rect(wx + 1, 4, 24, 4, high)
			buf.rect(wx + 12, 4, 1, 12, w)
			buf.rect(wx + 1, 9, 24, 1, w)
			switch sky {
				case .night:
					for (sx, sy) in [(3, 6), (17, 5), (8, 12), (21, 13)] where (t / 6 + sx) % 5 != 0 {
						buf.put(wx + sx, sy, 0xF6F1E6)
					}
				case .day:
					let cx = wx + 2 + (t / 24) % 6
					buf.rect(cx, 6, 5, 2, 0xFFFFFF)
					buf.rect(cx + 1, 5, 2, 1, 0xFFFFFF)
				case .dusk:
					break
			}
		}

		let (cx, cy) = (48, 10)
		for dx in -5...5 {
			for dy in -5...5 {
				let d2 = dx * dx + dy * dy
				if d2 <= 25 { buf.put(cx + dx, cy + dy, d2 > 16 ? k : w) }
			}
		}
		let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
		let hour = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
		for (length, angle, color) in [
			(2, hour.truncatingRemainder(dividingBy: 12) / 12 * 2 * .pi, k),
			(3, hour.truncatingRemainder(dividingBy: 1) * 2 * .pi, PixelArt.fixed["p"]!),
		] {
			for step in 1...length {
				buf.put(
					cx + Int((sin(angle) * Double(step)).rounded()),
					cy - Int((cos(angle) * Double(step)).rounded()),
					color)
			}
		}
		buf.put(cx, cy, k)
	}

	private static func drawCarpet(_ buf: inout PixelBuffer) {
		buf.rect(0, L.wallHeight, L.sceneWidth, L.sceneHeight - L.wallHeight, PixelArt.carpet)
		for y in L.wallHeight..<L.sceneHeight {
			let row = y - L.wallHeight
			guard row % 4 == 1 else { continue }
			for x in 0..<L.sceneWidth where (x + (row / 4) * 2) % 4 == 0 {
				buf.put(x, y, PixelArt.carpetDot)
			}
		}
		buf.rect(0, L.wallHeight, L.sceneWidth, 1, PixelArt.carpetDark)
	}

	private static func drawCell(_ buf: inout PixelBuffer, _ ox: Int, _ oy: Int, _ desk: DeskSnapshot?, frame t: Int) {
		let pal = PixelArt.fixed
		let p = L.partition
		buf.rect(ox + p.x, oy + p.y, p.w, p.h, pal["k"]!)
		buf.rect(ox + p.x + 1, oy + p.y + 1, p.w - 2, p.h - 1, pal["f"]!)
		buf.rect(ox + p.x + 1, oy + p.y + 1, p.w - 2, 1, pal["T"]!)
		for sx in stride(from: ox + p.x + 4, to: ox + p.x + p.w - 2, by: 6) {
			buf.rect(sx, oy + p.y + 3, 1, p.h - 4, pal["F"]!)
		}

		if let desk {
			buf.blit(PixelArt.chair, ox + L.chair.x, oy + L.chair.y, pal)
			drawCharacter(&buf, look: desk.look, ox + L.character.x, oy + L.character.y, activity: desk.activity, frame: t)
		}

		let top = L.deskTop
		let front = L.deskFront
		buf.rect(ox + top.x - 1, oy + top.y - 1, top.w + 2, top.h + front.h + 2, pal["k"]!)
		buf.rect(ox + top.x, oy + top.y, top.w, top.h, pal["d"]!)
		buf.rect(ox + top.x, oy + front.y, top.w, 1, pal["q"]!)
		buf.rect(ox + top.x, oy + front.y + 1, top.w, front.h - 1, pal["D"]!)
		buf.rect(ox + top.x + 1, oy + front.y + front.h + 1, top.w - 2, 2, PixelArt.carpetDark)

		guard let desk else {
			buf.blit(PixelArt.plant, ox + 30, oy + 18, pal)
			drawPlate(&buf, ox, oy, text: "VACANT", dim: true)
			return
		}

		buf.blit(PixelArt.monitor, ox + L.monitor.x, oy + L.monitor.y, pal)
		buf.blit(PixelArt.mug, ox + L.mug.x, oy + L.mug.y, pal)
		buf.blit(PixelArt.steam[(t / 4) % 2], ox + L.mug.x, oy + L.mug.y - 3, ["w": 0xE8EEF2])

		let ringing = desk.activity == .ringing || desk.activity == .dialing
		let jiggle = ringing && t % 10 < 6 ? (t % 2 == 1 ? -1 : 1) : 0
		let phx = ox + L.phone.x + jiggle
		let phy = oy + L.phone.y
		buf.blit(desk.hasLine ? PixelArt.phone : PixelArt.phoneDead, phx, phy, pal)

		var lamp = pal["o"]!
		if desk.hasLine {
			switch desk.activity {
				case .ringing, .dialing: lamp = t % 4 < 2 ? PixelArt.amber : pal["o"]!
				case .listening, .thinking, .speaking, .human: lamp = t % 8 < 5 ? PixelArt.mint : 0x3E8C6A
				case .idle: lamp = PixelArt.mint
			}
		}
		buf.put(phx + L.phoneLamp.x, phy + L.phoneLamp.y, lamp)
		if ringing, t % 10 < 6 {
			for (rx, ry) in [(-2, 0), (-3, 1), (-2, 2), (11, 0), (12, 1), (11, 2)] {
				buf.put(ox + L.phone.x + rx, phy + ry, PixelArt.amber)
			}
		}

		drawPlate(&buf, ox, oy, text: plateText(desk.name), dim: false)

		let bx = ox + L.bubble.x
		let by = oy + L.bubble.y
		switch desk.activity {
			case .thinking:
				drawBubble(&buf, bx, by)
				for i in 0...((t / 3) % 3) {
					buf.rect(bx + 3 + i * 4, by + 4, 2, 2, pal["k"]!)
				}
			case .speaking:
				drawBubble(&buf, bx, by)
				let heights = [1, 3, 5, 3, 2, 4]
				for i in 0..<5 {
					let h = heights[(t + i * 2) % 6]
					buf.rect(bx + 3 + i * 2, by + 4 - h / 2, 1, max(1, h), pal["p"]!)
				}
			case .human:
				drawBubble(&buf, bx, by)
				drawText(&buf, "YOU", bx + 2, by + 2, pal["p"]!)
			default:
				break
		}
	}

	private static func drawBubble(_ buf: inout PixelBuffer, _ x: Int, _ y: Int) {
		let k = PixelArt.fixed["k"]!
		buf.rect(x + 1, y, 13, 9, k)
		buf.rect(x, y + 1, 15, 7, k)
		buf.rect(x + 1, y + 1, 13, 7, PixelArt.fixed["w"]!)
		buf.put(x + 1, y + 9, k)
		buf.put(x, y + 10, k)
	}

	// MARK: - Nameplate

	static func plateText(_ name: String) -> String {
		let folded = name.uppercased().map { PixelArt.fold[$0] ?? $0 }
		let kept = String(folded.filter { PixelArt.font[$0] != nil }).trimmingCharacters(in: .whitespaces)
		return kept.isEmpty ? "?" : String(kept.prefix(L.nameMax))
	}

	private static func textWidth(_ text: String) -> Int {
		max(0, text.count * 4 - 1)
	}

	private static func drawText(_ buf: inout PixelBuffer, _ text: String, _ x: Int, _ y: Int, _ color: UInt32) {
		for (i, ch) in text.enumerated() {
			let glyph = PixelArt.font[PixelArt.fold[ch] ?? ch] ?? PixelArt.font["?"]!
			for (gy, row) in glyph.enumerated() {
				for (gx, px) in row.enumerated() where px == "#" {
					buf.put(x + i * 4 + gx, y + gy, color)
				}
			}
		}
	}

	private static func drawPlate(_ buf: inout PixelBuffer, _ ox: Int, _ oy: Int, text: String, dim: Bool) {
		let tw = textWidth(text)
		let w = max(17, tw + 6)
		let x = ox + L.cellWidth / 2 - w / 2
		let y = oy + L.plateY
		buf.rect(x, y, w, L.plateHeight, PixelArt.fixed["k"]!)
		buf.rect(x + 1, y + 1, w - 2, L.plateHeight - 2, dim ? PixelArt.fixed["N"]! : PixelArt.fixed["n"]!)
		if !dim {
			buf.rect(x + 1, y + 1, w - 2, 1, 0xF2D98C)
		}
		drawText(&buf, text, x + (w - tw) / 2, y + 2, dim ? 0x6E521C : PixelArt.fixed["t"]!)
	}
}
