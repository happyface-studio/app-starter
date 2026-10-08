import CoreGraphics
import Foundation

/// A sprite is a grid of palette roles; "." is transparent.
struct Sprite {
	let rows: [[Character]]

	init(_ rows: [String]) {
		self.rows = rows.map(Array.init)
	}
}

typealias Palette = [Character: UInt32]

/// RGBA pixel canvas the office is drawn into every frame, then shown as one nearest-neighbour image.
struct PixelBuffer {
	let width: Int
	let height: Int
	private(set) var bytes: [UInt8]

	init(width: Int, height: Int) {
		self.width = width
		self.height = height
		bytes = Array(repeating: 0, count: width * height * 4)
	}

	mutating func put(_ x: Int, _ y: Int, _ rgb: UInt32?) {
		guard let rgb, x >= 0, y >= 0, x < width, y < height else { return }
		let i = (y * width + x) * 4
		bytes[i] = UInt8((rgb >> 16) & 0xFF)
		bytes[i + 1] = UInt8((rgb >> 8) & 0xFF)
		bytes[i + 2] = UInt8(rgb & 0xFF)
		bytes[i + 3] = 0xFF
	}

	mutating func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ rgb: UInt32) {
		guard w > 0, h > 0 else { return }
		for yy in y..<(y + h) {
			for xx in x..<(x + w) {
				put(xx, yy, rgb)
			}
		}
	}

	mutating func blit(_ sprite: Sprite, _ x: Int, _ y: Int, _ palette: Palette) {
		for (dy, row) in sprite.rows.enumerated() {
			for (dx, role) in row.enumerated() where role != "." {
				put(x + dx, y + dy, palette[role] ?? 0xFF00FF)
			}
		}
	}

	func makeImage() -> CGImage? {
		let data = Data(bytes) as CFData
		guard let provider = CGDataProvider(data: data) else { return nil }
		return CGImage(
			width: width,
			height: height,
			bitsPerComponent: 8,
			bitsPerPixel: 32,
			bytesPerRow: width * 4,
			space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
			provider: provider,
			decode: nil,
			shouldInterpolate: false,
			intent: .defaultIntent
		)
	}
}
