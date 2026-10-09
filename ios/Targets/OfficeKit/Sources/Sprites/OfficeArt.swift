import CoreGraphics
import Foundation
import ImageIO
import SupabaseKit

/// The LimeZu office art that `ios/Tools/officeart/pack.py` writes into `Resources/OfficeArt`.
///
/// The PNGs are licensed for use in the app but not for redistribution, so they're gitignored.
/// `shared` is nil until someone runs the pack step locally; the views then fall back to the
/// procedural pixel renderer in `Pixel/`.
final class OfficeArt: @unchecked Sendable {
	static let shared: OfficeArt? = OfficeArt(bundle: Bundle(for: OfficeArt.self))

	let manifest: OfficeManifest
	let atlas: CGImage
	let background: CGImage

	private let bundle: Bundle
	private let lock = NSLock()
	private var frames: [String: CGImage] = [:]
	private var layers: [String: CGImage] = [:]
	private var strips: [Look: CGImage] = [:]
	private var plates: [String: CGImage] = [:]
	private var portraits: [PortraitKey: CGImage] = [:]
	private var thumbnails: [Look: CGImage] = [:]

	init?(bundle: Bundle) {
		guard
			let url = bundle.url(forResource: "office", withExtension: "json"),
			let data = try? Data(contentsOf: url),
			let manifest = try? JSONDecoder().decode(OfficeManifest.self, from: data),
			let atlas = Self.png(manifest.atlas, in: bundle),
			let background = Self.png(manifest.background, in: bundle)
		else { return nil }
		self.bundle = bundle
		self.manifest = manifest
		self.atlas = atlas
		self.background = background
	}

	private static func png(_ name: String, in bundle: Bundle) -> CGImage? {
		guard
			let url = bundle.url(forResource: name, withExtension: "png"),
			let source = CGImageSourceCreateWithURL(url as CFURL, nil)
		else { return nil }
		return CGImageSourceCreateImageAtIndex(source, 0, nil)
	}

	private func cached<Key: Hashable>(
		_ cache: ReferenceWritableKeyPath<OfficeArt, [Key: CGImage]>, _ key: Key, make: () -> CGImage?
	) -> CGImage? {
		lock.lock()
		if let hit = self[keyPath: cache][key] {
			lock.unlock()
			return hit
		}
		lock.unlock()
		guard let image = make() else { return nil }
		lock.lock()
		if self[keyPath: cache].count > 120 { self[keyPath: cache].removeAll() }
		self[keyPath: cache][key] = image
		lock.unlock()
		return image
	}

	// MARK: - Atlas sprites

	func sprite(_ name: String) -> OfficeManifest.Sprite? {
		manifest.sprites[name]
	}

	/// Frame `index` (wrapped) of an atlas sprite.
	func frame(_ name: String, _ index: Int = 0) -> CGImage? {
		guard let s = manifest.sprites[name], !s.frames.isEmpty else { return nil }
		let i = wrap(index, s.frames.count)
		return cached(\.frames, "\(name)#\(i)") {
			let origin = s.frames[i]
			return atlas.cropping(to: CGRect(x: origin[0], y: origin[1], width: s.w, height: s.h))
		}
	}

	/// Which frame an animated sprite shows at `time` seconds.
	func frameIndex(_ name: String, at time: TimeInterval) -> Int {
		guard let s = manifest.sprites[name], s.fps > 0 else { return 0 }
		return Int(time * s.fps) % max(1, s.frames.count)
	}

	// MARK: - Characters

	enum Face: String {
		case right, up, left, down
	}

	private var catalog: OfficeManifest.Characters { manifest.characters }

	func layerNames(for look: Look) -> [String] {
		let c = catalog
		var names = [
			pick(c.bodies, look.skin),
			pick(c.eyes, look.eyes),
			pick(pick(c.outfits, look.shirt), look.shirtColor),
			pick(pick(c.hairs, look.hair), look.hairColor),
		]
		if look.accessory > 0, !c.accessories.isEmpty {
			names.append(pick(c.accessories, look.accessory - 1).file)
		}
		return names
	}

	/// Every animation frame for this look, composited from the generator layers into one strip.
	func strip(for look: Look) -> CGImage? {
		cached(\.strips, look) {
			let images = layerNames(for: look).compactMap(layer)
			guard let first = images.first else { return nil }
			let ctx = Self.context(width: first.width, height: first.height)
			for image in images {
				ctx?.draw(image, in: CGRect(x: 0, y: 0, width: first.width, height: first.height))
			}
			return ctx?.makeImage()
		}
	}

	private func layer(_ name: String) -> CGImage? {
		cached(\.layers, name) { Self.png(name, in: bundle) }
	}

	/// Index into a character strip. Idle and walk have six frames per direction; the phone
	/// animation faces down: frames 0-2 take the phone out, 3-8 loop, 9-11 put it away.
	func characterFrameIndex(_ anim: String, face: Face = .down, _ i: Int) -> Int {
		guard let a = catalog.anims[anim] else { return 0 }
		if let perDir = a.perDir, let dirs = a.dirs {
			let dir = dirs.firstIndex(of: face.rawValue) ?? 0
			return a.start + dir * perDir + wrap(i, perDir)
		}
		return a.start + wrap(i, a.count ?? 1)
	}

	var characterSize: (w: Int, h: Int) { (catalog.frameW, catalog.frameH) }

	func characterFrame(_ look: Look, index: Int) -> CGImage? {
		strip(for: look)?.cropping(
			to: CGRect(x: index * catalog.frameW, y: 0, width: catalog.frameW, height: catalog.frameH))
	}

	/// Head and shoulders on a 20x20 canvas, for headers, the call screen and the dock.
	func portrait(look: Look, activity: DeskActivity, hasLine: Bool, time: TimeInterval) -> CGImage? {
		let i = Int(time * 5) % 6
		let dialing = activity == .dialing
		let index = dialing ? characterFrameIndex("phone", 3 + i) : characterFrameIndex("idle", face: .down, i)
		let headset = dialing || !hasLine ? nil : (activity.isTalking ? "headset_live" : "headset")
		let key = PortraitKey(look: look, index: index, headset: headset)
		return cached(\.portraits, key) {
			guard let ctx = Self.context(width: 20, height: 20), let body = characterFrame(look, index: index) else {
				return nil
			}
			Self.draw(body, in: ctx, x: 2, y: -6, canvasHeight: 20)
			if let headset, let overlay = frame(headset, i) {
				Self.draw(overlay, in: ctx, x: 2, y: -6, canvasHeight: 20)
			}
			return ctx.makeImage()
		}
	}

	/// The look facing forward, cropped to 16x22, for the look editor. Composites just that frame,
	/// so browsing options doesn't fill the strip cache.
	func thumbnail(_ look: Look) -> CGImage? {
		cached(\.thumbnails, look) {
			let crop = CGRect(
				x: characterFrameIndex("idle", face: .down, 0) * catalog.frameW, y: 7, width: catalog.frameW, height: 22)
			guard let ctx = Self.context(width: catalog.frameW, height: 22) else { return nil }
			for name in layerNames(for: look) {
				if let part = layer(name)?.cropping(to: crop) {
					ctx.draw(part, in: CGRect(x: 0, y: 0, width: part.width, height: part.height))
				}
			}
			return ctx.makeImage()
		}
	}

	// MARK: - Look editor options

	var skinCount: Int { catalog.bodies.count }
	var eyesCount: Int { catalog.eyes.count }
	var hairStyleCount: Int { catalog.hairs.count }
	func hairColorCount(style: Int) -> Int { pick(catalog.hairs, style).count }
	var outfitCount: Int { catalog.outfits.count }
	func outfitColorCount(style: Int) -> Int { pick(catalog.outfits, style).count }
	/// Option 0 is "nothing"; the rest map to `accessories[i - 1]`.
	var accessoryLabels: [String] {
		var seen: [String: Int] = [:]
		return ["None"]
			+ catalog.accessories.map { accessory in
				seen[accessory.label, default: 0] += 1
				return "\(accessory.label) \(seen[accessory.label, default: 1])"
			}
	}

	// MARK: - Nameplates

	func plate(_ name: String, dim: Bool) -> CGImage? {
		let text = Self.plateText(name, font: manifest.font, fold: manifest.fold)
		return cached(\.plates, "\(text)|\(dim)") {
			let tw = text.count * 4 - 1
			let w = max(17, tw + 6)
			var buf = PixelBuffer(width: w, height: 9)
			buf.rect(0, 0, w, 9, 0x3A3A50)
			buf.rect(1, 1, w - 2, 7, dim ? 0xA88536 : 0xE0BC62)
			if !dim { buf.rect(1, 1, w - 2, 1, 0xF2D98C) }
			let ox = (w - tw) / 2
			for (i, ch) in text.enumerated() {
				for (gy, row) in (manifest.font[String(ch)] ?? []).enumerated() {
					for (gx, px) in row.enumerated() where px == "#" {
						buf.put(ox + i * 4 + gx, 2 + gy, dim ? 0x6E521C : 0x4A3518)
					}
				}
			}
			return buf.makeImage()
		}
	}

	static func plateText(_ name: String, font: [String: [String]], fold: [String: String]) -> String {
		let folded = name.uppercased().map { fold[String($0)] ?? String($0) }.joined()
		let kept = folded.filter { font[String($0)] != nil }.trimmingCharacters(in: .whitespaces)
		return kept.isEmpty ? "?" : String(kept.prefix(8))
	}

	// MARK: - Helpers

	private func pick<T>(_ options: [T], _ i: Int) -> T {
		options[wrap(i, options.count)]
	}

	private func wrap(_ i: Int, _ n: Int) -> Int {
		guard n > 0 else { return 0 }
		return ((i % n) + n) % n
	}

	static func context(width: Int, height: Int) -> CGContext? {
		let ctx = CGContext(
			data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
			space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
		ctx?.interpolationQuality = .none
		return ctx
	}

	/// Draws with a top-left origin, like the art coordinates.
	static func draw(_ image: CGImage, in ctx: CGContext, x: Int, y: Int, canvasHeight: Int) {
		ctx.draw(
			image, in: CGRect(x: x, y: canvasHeight - y - image.height, width: image.width, height: image.height))
	}
}

private struct PortraitKey: Hashable {
	let look: Look
	let index: Int
	let headset: String?
}

/// `office.json`, written by `ios/Tools/officeart/pack.py`. Coordinates are art pixels, top-left origin.
struct OfficeManifest: Decodable {
	struct Size: Decodable {
		let w: Int
		let h: Int
		let floorTop: Int
	}

	struct Sprite: Decodable {
		let w: Int
		let h: Int
		let dx: Int
		let dy: Int
		let fps: Double
		let frames: [[Int]]
	}

	struct Prop: Decodable {
		let sprite: String
		let x: Int
		let y: Int
		let z: Int
	}

	struct Point: Decodable {
		let x: Int
		let y: Int
	}

	struct Item: Decodable {
		let name: String
		let x: Int
		let y: Int
	}

	struct Plate: Decodable {
		let cx: Int
		let y: Int
	}

	struct Rect: Decodable {
		let x: Int
		let y: Int
		let w: Int
		let h: Int
	}

	struct Station: Decodable {
		let seat: Int
		let desk: Point
		let chair: Point
		let feet: Point
		let monitor: Point
		let phone: Point
		let item: Item?
		let plate: Plate
		let bubble: Point
		let tap: Rect
		let exit: Point
		/// Walk paths from the seat to each place in `pois`, as [x, y] corners.
		let paths: [String: [[Int]]]
	}

	struct Place: Decodable {
		let x: Int
		let y: Int
		let face: String
	}

	struct Anim: Decodable {
		let start: Int
		let perDir: Int?
		let dirs: [String]?
		let count: Int?
		let loop: [Int]?
	}

	struct Accessory: Decodable {
		let label: String
		let file: String
	}

	struct Characters: Decodable {
		let frameW: Int
		let frameH: Int
		let anims: [String: Anim]
		let bodies: [String]
		let eyes: [String]
		let outfits: [[String]]
		let hairs: [[String]]
		let accessories: [Accessory]
	}

	let version: Int
	let scene: Size
	let atlas: String
	let background: String
	let sprites: [String: Sprite]
	let props: [Prop]
	let desk: String
	let stations: [Station]
	let pois: [String: Place]
	let font: [String: [String]]
	let fold: [String: String]
	let characters: Characters
}
