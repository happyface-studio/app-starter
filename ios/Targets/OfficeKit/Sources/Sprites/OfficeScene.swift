import SpriteKit
import SupabaseKit

/// The office as a SpriteKit scene, built from `office.json`. Mirrors `ios/Tools/officeart/render.py`
/// and the web preview: everything is depth-sorted by its bottom edge, and a seated deskmate's feet
/// sit just behind the desk so the desk top hides their legs.
///
/// Idle deskmates get up now and then and walk to the water cooler, the vending machine, the
/// window or the cat along paths baked by the pack step. When their phone rings they hurry back.
final class OfficeScene: SKScene {
	private let art: OfficeArt
	private let reduceMotion: Bool
	private var seats: [DeskSnapshot?] = []
	private var stations: [StationNodes] = []
	private var agents: [Agent] = []
	private var textures: [String: SKTexture] = [:]
	private var characterTextures: [Look: SKTexture] = [:]
	private var characterFrames: [CharacterFrameKey: SKTexture] = [:]
	private var plateKeys: [String] = []
	private var clock: TimeInterval = 0
	private var lastUpdate: TimeInterval?

	private var M: OfficeManifest { art.manifest }
	private var sceneHeight: CGFloat { CGFloat(M.scene.h) }

	init(art: OfficeArt, reduceMotion: Bool) {
		self.art = art
		self.reduceMotion = reduceMotion
		super.init(size: CGSize(width: art.manifest.scene.w, height: art.manifest.scene.h))
		scaleMode = .fill
		anchorPoint = .zero
		backgroundColor = SKColor(red: 0x1F / 255, green: 0x4D / 255, blue: 0x57 / 255, alpha: 1)
		build()
	}

	@available(*, unavailable)
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - Building

	private func texture(_ name: String, _ index: Int = 0) -> SKTexture? {
		let key = "\(name)#\(index)"
		if let hit = textures[key] { return hit }
		guard let image = art.frame(name, index) else { return nil }
		let texture = SKTexture(cgImage: image)
		texture.filteringMode = .nearest
		textures[key] = texture
		return texture
	}

	private func image(_ image: CGImage?) -> SKTexture? {
		guard let image else { return nil }
		let texture = SKTexture(cgImage: image)
		texture.filteringMode = .nearest
		return texture
	}

	/// A sprite node placed by its top-left corner in art coordinates.
	private func node(_ texture: SKTexture?, z: CGFloat) -> SKSpriteNode {
		let node = SKSpriteNode(texture: texture)
		node.anchorPoint = CGPoint(x: 0, y: 1)
		node.zPosition = z
		if let texture { node.size = texture.size() }
		addChild(node)
		return node
	}

	private func place(_ node: SKNode, _ x: CGFloat, _ y: CGFloat) {
		node.position = CGPoint(x: x, y: sceneHeight - y)
	}

	private func placeSprite(_ node: SKSpriteNode, _ name: String, frame: Int, x: CGFloat, y: CGFloat) {
		guard let s = art.sprite(name), let texture = texture(name, frame) else {
			node.isHidden = true
			return
		}
		node.texture = texture
		node.size = texture.size()
		node.isHidden = false
		place(node, x + CGFloat(s.dx), y + CGFloat(s.dy))
	}

	private func build() {
		let background = node(image(art.background), z: -10_000)
		place(background, 0, 0)

		for prop in M.props {
			guard let s = art.sprite(prop.sprite) else { continue }
			let n = node(texture(prop.sprite), z: CGFloat(prop.z))
			place(n, CGFloat(prop.x + s.dx), CGFloat(prop.y + s.dy))
			if s.frames.count > 1, s.fps > 0, !reduceMotion {
				let frames = (0..<s.frames.count).compactMap { texture(prop.sprite, $0) }
				n.run(.repeatForever(.animate(with: frames, timePerFrame: 1 / s.fps)))
			}
		}

		let deskHeight = CGFloat(art.sprite(M.desk)?.h ?? 23)
		for st in M.stations {
			let base = CGFloat(st.desk.y) + deskHeight
			let nodes = StationNodes(
				desk: node(texture(M.desk), z: base),
				chair: node(texture("chair"), z: CGFloat(st.feet.y - 2)),
				monitor: node(texture("monitor_back"), z: base + 1),
				item: node(nil, z: base + 1.5),
				vacantPlant: node(texture("plant_small"), z: base + 1),
				phone: node(texture("phone_rotary"), z: base + 2),
				ring: node(image(Self.ringMarks()), z: base + 3),
				plate: node(nil, z: base + 3),
				character: node(nil, z: CGFloat(st.feet.y)),
				headset: node(nil, z: CGFloat(st.feet.y) + 0.5),
				emote: node(nil, z: 10_000)
			)
			placeSprite(nodes.desk, M.desk, frame: 0, x: CGFloat(st.desk.x), y: CGFloat(st.desk.y))
			placeSprite(nodes.chair, "chair", frame: 0, x: CGFloat(st.chair.x), y: CGFloat(st.chair.y))
			placeSprite(nodes.monitor, "monitor_back", frame: 0, x: CGFloat(st.monitor.x), y: CGFloat(st.monitor.y))
			placeSprite(nodes.vacantPlant, "plant_small", frame: 0, x: CGFloat(st.desk.x + 12), y: CGFloat(st.desk.y - 8))
			place(nodes.ring, CGFloat(st.phone.x - 3), CGFloat(st.phone.y + 1))
			nodes.ring.isHidden = true
			stations.append(nodes)
			agents.append(Agent(seat: st.seat, x: CGFloat(st.feet.x), y: CGFloat(st.feet.y), wait: 4 + Double(st.seat) * 3 + .random(in: 0..<8)))
		}
		plateKeys = Array(repeating: "", count: M.stations.count)
		apply(seats: Array(repeating: nil, count: M.stations.count))
	}

	private static func ringMarks() -> CGImage? {
		var buf = PixelBuffer(width: 22, height: 6)
		for (x, y) in [(0, 1), (1, 2), (0, 3), (21, 1), (20, 2), (21, 3)] {
			buf.put(x, y, 0xF4B23E)
		}
		return buf.makeImage()
	}

	// MARK: - State from the app

	func apply(seats newSeats: [DeskSnapshot?]) {
		for (seat, st) in M.stations.enumerated() {
			let desk = seat < newSeats.count ? newSeats[seat] : nil
			let old = seat < seats.count ? seats[seat] : nil
			let nodes = stations[seat]
			let occupied = desk != nil
			nodes.monitor.isHidden = !occupied
			nodes.vacantPlant.isHidden = occupied
			nodes.phone.isHidden = !(desk?.hasLine ?? false)
			nodes.character.isHidden = !occupied
			if let item = st.item, occupied {
				placeSprite(nodes.item, item.name, frame: 0, x: CGFloat(item.x), y: CGFloat(item.y))
			} else {
				nodes.item.isHidden = true
			}
			let plateKey = desk.map { "desk:" + $0.name } ?? "vacant"
			if plateKeys[seat] != plateKey, let plate = image(art.plate(desk?.name ?? "VACANT", dim: desk == nil)) {
				plateKeys[seat] = plateKey
				nodes.plate.texture = plate
				nodes.plate.size = plate.size()
				place(nodes.plate, CGFloat(st.plate.cx - Int(plate.size().width) / 2), CGFloat(st.plate.y))
			}
			if (old == nil) != (desk == nil) {
				agents[seat].sit(at: st)
			}
		}
		seats = newSeats
	}

	// MARK: - Frame loop

	override func update(_ currentTime: TimeInterval) {
		let dt = min(0.1, lastUpdate.map { currentTime - $0 } ?? 0)
		lastUpdate = currentTime
		if !reduceMotion { clock += dt }
		for seat in agents.indices {
			let desk = seat < seats.count ? seats[seat] : nil
			agents[seat].update(
				dt: dt, now: clock, activity: desk?.activity ?? .idle, occupied: desk != nil, wanders: !reduceMotion,
				manifest: M)
			draw(seat: seat, desk: desk)
		}
	}

	private func draw(seat: Int, desk: DeskSnapshot?) {
		let st = M.stations[seat]
		let nodes = stations[seat]
		let agent = agents[seat]
		let activity = desk?.activity ?? .idle

		let ringOn = activity == .ringing && Int(clock * 10) % 10 < 6
		if let desk, desk.hasLine {
			let jiggle: CGFloat = ringOn && !reduceMotion ? (Int(clock * 12) % 2 == 1 ? 1 : -1) : 0
			place(nodes.phone, CGFloat(st.phone.x) + jiggle, CGFloat(st.phone.y))
		}
		nodes.ring.isHidden = !(ringOn && desk?.hasLine == true)
		if let item = st.item, desk != nil, let s = art.sprite(item.name), s.frames.count > 1 {
			nodes.item.texture = texture(item.name, art.frameIndex(item.name, at: clock))
		}

		guard let desk, let strip = characterTexture(desk.look) else {
			nodes.character.isHidden = true
			nodes.headset.isHidden = true
			nodes.emote.isHidden = true
			return
		}

		let x = agent.x.rounded() - 8
		let y = agent.y.rounded() - 31
		let index: Int
		var headset: String?
		let idleFrame = Int(clock * 5) % 6
		switch agent.mode {
			case .seated:
				if activity == .dialing {
					let k = Int((clock - (agent.phoneSince ?? clock)) * 8)
					index = art.characterFrameIndex("phone", k < 3 ? k : 3 + (k - 3) % 6)
				} else {
					index = art.characterFrameIndex("idle", face: .down, idleFrame)
					if desk.hasLine { headset = activity.isTalking ? "headset_live" : "headset" }
				}
			case .atPlace:
				index = art.characterFrameIndex("idle", face: agent.face, idleFrame)
			case .walking, .returning:
				index = art.characterFrameIndex("walk", face: agent.face, Int(agent.walkTime * 10))
		}
		nodes.character.isHidden = false
		nodes.character.texture = characterFrame(strip, look: desk.look, index: index)
		nodes.character.size = CGSize(width: art.characterSize.w, height: art.characterSize.h)
		// Seat offset keeps two people on the same row in a fixed order (sibling order is ignored).
		let z = agent.y + CGFloat(seat) * 0.01
		nodes.character.zPosition = z
		place(nodes.character, x, y)

		if let headset {
			placeSprite(nodes.headset, headset, frame: idleFrame, x: x, y: y)
			nodes.headset.zPosition = z + 0.5
		} else {
			nodes.headset.isHidden = true
		}

		let emote: String? =
			switch activity {
				case .ringing: "emote_ring"
				case .thinking: "emote_think"
				case .speaking: "emote_speak"
				case .human: "emote_boss"
				default: nil
			}
		if let emote, let s = art.sprite(emote) {
			let seated = agent.mode == .seated
			let bx = seated ? CGFloat(st.bubble.x) : x + 14
			let by = seated ? CGFloat(st.bubble.y) : y + 20
			placeSprite(nodes.emote, emote, frame: art.frameIndex(emote, at: clock), x: bx - CGFloat(s.dx), y: by - CGFloat(s.h + s.dy))
		} else {
			nodes.emote.isHidden = true
		}
	}

	private func characterTexture(_ look: Look) -> SKTexture? {
		if let hit = characterTextures[look] { return hit }
		guard let strip = art.strip(for: look) else { return nil }
		let texture = SKTexture(cgImage: strip)
		texture.filteringMode = .nearest
		if characterTextures.count > 24 { characterTextures.removeAll() }
		characterTextures[look] = texture
		return texture
	}

	private func characterFrame(_ strip: SKTexture, look: Look, index: Int) -> SKTexture {
		let key = CharacterFrameKey(look: look, index: index)
		if let hit = characterFrames[key] { return hit }
		let size = strip.size()
		let w = CGFloat(art.characterSize.w) / size.width
		let frame = SKTexture(rect: CGRect(x: CGFloat(index) * w, y: 0, width: w, height: 1), in: strip)
		frame.filteringMode = .nearest
		if characterFrames.count > 600 { characterFrames.removeAll() }
		characterFrames[key] = frame
		return frame
	}
}

private struct CharacterFrameKey: Hashable {
	let look: Look
	let index: Int
}

private struct StationNodes {
	let desk: SKSpriteNode
	let chair: SKSpriteNode
	let monitor: SKSpriteNode
	let item: SKSpriteNode
	let vacantPlant: SKSpriteNode
	let phone: SKSpriteNode
	let ring: SKSpriteNode
	let plate: SKSpriteNode
	let character: SKSpriteNode
	let headset: SKSpriteNode
	let emote: SKSpriteNode
}

/// One deskmate's position and errand. Coordinates are the feet, in art pixels.
private struct Agent {
	enum Mode {
		case seated, walking, atPlace, returning
	}

	let seat: Int
	var x: CGFloat
	var y: CGFloat
	var face: OfficeArt.Face = .down
	var mode: Mode = .seated
	var path: [CGPoint] = []
	var segment = 0
	var place: String?
	var wait: TimeInterval
	var walkTime: TimeInterval = 0
	var phoneSince: TimeInterval?

	init(seat: Int, x: CGFloat, y: CGFloat, wait: TimeInterval) {
		self.seat = seat
		self.x = x
		self.y = y
		self.wait = wait
	}

	mutating func sit(at station: OfficeManifest.Station) {
		x = CGFloat(station.feet.x)
		y = CGFloat(station.feet.y)
		mode = .seated
		face = .down
		path = []
		wait = .random(in: 6..<16)
	}

	mutating func update(
		dt: TimeInterval, now: TimeInterval, activity: DeskActivity, occupied: Bool, wanders: Bool,
		manifest: OfficeManifest
	) {
		guard occupied else { return }
		let busy = activity != .idle
		if activity == .dialing, mode == .seated {
			if phoneSince == nil { phoneSince = now }
		} else {
			phoneSince = nil
		}

		switch mode {
			case .seated:
				guard !busy, wanders else { return }
				wait -= dt
				if wait <= 0 {
					let station = manifest.stations[seat]
					guard let name = manifest.pois.keys.randomElement(), let corners = station.paths[name] else {
						wait = 5
						return
					}
					place = name
					start(corners.map { CGPoint(x: $0[0], y: $0[1]) }, .walking)
				}
				return
			case .atPlace:
				wait -= dt
				if wait <= 0 || busy { start(path.reversed(), .returning) }
				return
			case .walking:
				if busy {
					// Turn around mid-walk: back to the last corner, then retrace to the seat.
					start([CGPoint(x: x, y: y)] + path[..<segment].reversed(), .returning)
				}
			case .returning:
				break
		}

		let speed: CGFloat = mode == .returning && busy ? 64 : 30
		var step = speed * CGFloat(dt)
		while step > 0, segment < path.count {
			let target = path[segment]
			let dx = target.x - x
			let dy = target.y - y
			let distance = (dx * dx + dy * dy).squareRoot()
			if distance > 0.01 {
				face = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
			}
			if distance <= step {
				x = target.x
				y = target.y
				segment += 1
				step -= distance
			} else {
				x += dx / distance * step
				y += dy / distance * step
				step = 0
			}
		}
		walkTime += dt * Double(speed / 30)
		if segment >= path.count {
			if mode == .walking {
				mode = .atPlace
				face = place.flatMap { manifest.pois[$0] }.flatMap { OfficeArt.Face(rawValue: $0.face) } ?? .up
				wait = .random(in: 2.5..<5.5)
			} else {
				mode = .seated
				face = .down
				wait = .random(in: 10..<24)
			}
		}
	}

	private mutating func start(_ corners: [CGPoint], _ newMode: Mode) {
		path = corners
		segment = 1
		mode = newMode
	}
}
