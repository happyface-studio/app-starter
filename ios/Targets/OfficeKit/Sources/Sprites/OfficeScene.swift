import SpriteKit
import SupabaseKit

/// The office as a SpriteKit scene, built from `office.json`. Mirrors `ios/Tools/officeart/render.py`
/// and the web preview: everything is depth-sorted by its bottom edge, and a seated deskmate's feet
/// sit just behind the desk so the desk top hides their legs.
///
/// Idle deskmates get up now and then for a break: the cooler, the copier, the kitchen (fridge,
/// coffee, the table, the sofa), along paths baked by the pack step. When their phone rings they
/// hurry back. Now and then a visitor comes in, checks in at reception, waits on the couch with a
/// magazine and leaves. Each place takes one person at a time.
final class OfficeScene: SKScene {
	private let art: OfficeArt
	private let reduceMotion: Bool
	private var seats: [DeskSnapshot?] = []
	private var stations: [StationNodes] = []
	private var agents: [Agent] = []
	private var guests: [Guest] = []
	private var guestNodes: [SKSpriteNode] = []
	private var nextGuest: TimeInterval = 6
	private var taken: Set<String> = []
	private let staffPlaces: [String]
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
		staffPlaces = art.manifest.pois.filter { $0.value.who == "staff" }.map(\.key).sorted()
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
		guestNodes = (0..<Self.maxGuests).map { _ in
			let n = node(nil, z: 0)
			n.isHidden = true
			return n
		}
		plateKeys = Array(repeating: "", count: M.stations.count)
		apply(seats: Array(repeating: nil, count: M.stations.count))
	}

	private static let maxGuests = 2

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
				if let place = agents[seat].walker.place { taken.remove(place) }
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
				manifest: M, places: staffPlaces, taken: &taken)
			draw(seat: seat, desk: desk)
		}
		if !reduceMotion { updateGuests(dt: dt) }
		drawGuests()
	}

	// MARK: - Visitors

	private func updateGuests(dt: TimeInterval) {
		guard let plan = M.guests else { return }
		nextGuest -= dt
		if nextGuest <= 0 {
			spawnGuest(plan)
			nextGuest = .random(in: 22..<47)
		}
		for i in guests.indices {
			guests[i].update(dt: dt, plan: plan, manifest: M)
		}
		for guest in guests where guest.mode == .gone {
			if let place = guest.walker.place { taken.remove(place) }
		}
		guests.removeAll { $0.mode == .gone }
	}

	private func spawnGuest(_ plan: OfficeManifest.Guests) {
		let receptionBusy = guests.contains { $0.mode == .arriving || $0.mode == .atDesk }
		guard guests.count < Self.maxGuests, !receptionBusy,
			let seat = plan.seats.filter({ !taken.contains($0) }).randomElement()
		else { return }
		taken.insert(seat)
		guests.append(Guest(look: .random(), seat: seat, arrive: plan.arrive))
	}

	private func drawGuests() {
		for (slot, node) in guestNodes.enumerated() {
			guard slot < guests.count, let strip = characterTexture(guests[slot].look) else {
				node.isHidden = true
				continue
			}
			let guest = guests[slot]
			// At the counter they stand; their seat's pose (reading) only applies once they're in it.
			let index =
				guest.mode == .atDesk
				? art.characterFrameIndex("idle", face: guest.walker.face, Int(clock * 5))
				: awayFrame(guest.walker, arrived: guest.mode == .waiting)
			node.isHidden = false
			node.texture = characterFrame(strip, look: guest.look, index: index)
			node.size = CGSize(width: art.characterSize.w, height: art.characterSize.h)
			node.zPosition = depth(of: guest.walker) + 0.1 + CGFloat(slot) * 0.01
			place(node, guest.walker.x.rounded() - 8, guest.walker.y.rounded() - 31)
		}
	}

	// MARK: - People away from their desk

	/// Draw order: someone in a seat (or stepping into it) uses the seat's z, so they show on top of it.
	private func depth(of walker: Walker) -> CGFloat {
		if let name = walker.place, let poi = M.pois[name], let approach = poi.approach, let z = poi.z,
			approach.count == 2, abs(walker.x - CGFloat(poi.x)) < 0.5, walker.y < CGFloat(approach[1]) - 0.01
		{
			return max(CGFloat(z), walker.y)
		}
		return walker.y
	}

	private func awayFrame(_ walker: Walker, arrived: Bool) -> Int {
		guard arrived else { return art.characterFrameIndex("walk", face: walker.face, Int(walker.walkTime * 10)) }
		let pose = walker.place.flatMap { M.pois[$0]?.pose } ?? "idle"
		if pose == "read" { return art.characterFrameIndex("read", Int(clock * 3)) }
		return art.characterFrameIndex(pose, face: walker.face, Int(clock * 5))
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

		let x = agent.walker.x.rounded() - 8
		let y = agent.walker.y.rounded() - 31
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
				index = awayFrame(agent.walker, arrived: true)
			case .walking, .returning:
				index = awayFrame(agent.walker, arrived: false)
		}
		nodes.character.isHidden = false
		nodes.character.texture = characterFrame(strip, look: desk.look, index: index)
		nodes.character.size = CGSize(width: art.characterSize.w, height: art.characterSize.h)
		// Seat offset keeps two people on the same row in a fixed order (sibling order is ignored).
		let z = (agent.mode == .seated ? agent.walker.y : depth(of: agent.walker)) + CGFloat(seat) * 0.01
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

/// Someone moving along a baked path. Coordinates are the feet, in art pixels.
private struct Walker {
	var x: CGFloat
	var y: CGFloat
	var face: OfficeArt.Face = .down
	var path: [CGPoint] = []
	var segment = 0
	/// The place (a key in the manifest's `pois`) they're headed to, at, or coming back from.
	var place: String?
	var walkTime: TimeInterval = 0

	mutating func start(_ corners: [CGPoint]) {
		path = corners
		segment = 1
	}

	/// Moves along the path. Returns true once at the end.
	mutating func walk(dt: TimeInterval, speed: CGFloat) -> Bool {
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
		return segment >= path.count
	}
}

private func points(_ corners: [[Int]]) -> [CGPoint] {
	corners.compactMap { $0.count == 2 ? CGPoint(x: $0[0], y: $0[1]) : nil }
}

/// One deskmate: at their desk, or on a break.
private struct Agent {
	enum Mode {
		case seated, walking, atPlace, returning
	}

	let seat: Int
	var walker: Walker
	var mode: Mode = .seated
	var wait: TimeInterval
	var phoneSince: TimeInterval?

	init(seat: Int, x: CGFloat, y: CGFloat, wait: TimeInterval) {
		self.seat = seat
		walker = Walker(x: x, y: y)
		self.wait = wait
	}

	mutating func sit(at station: OfficeManifest.Station) {
		walker = Walker(x: CGFloat(station.feet.x), y: CGFloat(station.feet.y))
		mode = .seated
		wait = .random(in: 6..<16)
	}

	mutating func update(
		dt: TimeInterval, now: TimeInterval, activity: DeskActivity, occupied: Bool, wanders: Bool,
		manifest: OfficeManifest, places: [String], taken: inout Set<String>
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
				guard wait <= 0 else { return }
				let station = manifest.stations[seat]
				guard
					let name = places.filter({ !taken.contains($0) && station.paths[$0] != nil }).randomElement(),
					let corners = station.paths[name]
				else {
					wait = 5
					return
				}
				taken.insert(name)
				walker.place = name
				walker.start(points(corners))
				mode = .walking
				return
			case .atPlace:
				wait -= dt
				if wait <= 0 || busy {
					walker.start(walker.path.reversed())
					mode = .returning
				}
				return
			case .walking:
				if busy {
					// Turn around mid-walk: back to the last corner, then retrace to the desk.
					walker.start([CGPoint(x: walker.x, y: walker.y)] + walker.path.prefix(walker.segment).reversed())
					mode = .returning
				}
			case .returning:
				break
		}

		guard walker.walk(dt: dt, speed: mode == .returning && busy ? 64 : 30) else { return }
		if mode == .walking {
			mode = .atPlace
			let poi = walker.place.flatMap { manifest.pois[$0] }
			walker.face = poi.flatMap { OfficeArt.Face(rawValue: $0.face) } ?? .up
			wait = (poi?.pose == nil ? 3 : 8) + .random(in: 0..<4)
		} else {
			if let place = walker.place { taken.remove(place) }
			walker.place = nil
			mode = .seated
			walker.face = .down
			wait = .random(in: 10..<24)
		}
	}
}

/// A visitor: in through the door, check in at reception, wait in a seat, out again.
private struct Guest {
	enum Mode {
		case arriving, atDesk, toSeat, waiting, leaving, gone
	}

	let look: Look
	var walker: Walker
	var mode: Mode = .arriving
	var wait: TimeInterval = 0

	init(look: Look, seat: String, arrive: [[Int]]) {
		self.look = look
		let path = points(arrive)
		walker = Walker(x: path.first?.x ?? 0, y: path.first?.y ?? 0, face: .up)
		walker.place = seat
		walker.start(path)
	}

	mutating func update(dt: TimeInterval, plan: OfficeManifest.Guests, manifest: OfficeManifest) {
		guard let seat = walker.place else {
			mode = .gone
			return
		}
		switch mode {
			case .atDesk, .waiting:
				wait -= dt
				guard wait <= 0 else { return }
				if mode == .atDesk {
					walker.start(points(plan.toSeat[seat] ?? []))
					mode = .toSeat
				} else {
					walker.start(points(plan.leave[seat] ?? []))
					mode = .leaving
				}
				return
			case .gone:
				return
			case .arriving, .toSeat, .leaving:
				break
		}
		guard walker.walk(dt: dt, speed: 26) else { return }
		switch mode {
			case .arriving:
				mode = .atDesk
				walker.face = OfficeArt.Face(rawValue: plan.desk.face) ?? .up
				wait = 2.5
			case .toSeat:
				mode = .waiting
				walker.face = manifest.pois[seat].flatMap { OfficeArt.Face(rawValue: $0.face) } ?? .down
				wait = .random(in: 10..<18)
			default:
				mode = .gone
		}
	}
}
