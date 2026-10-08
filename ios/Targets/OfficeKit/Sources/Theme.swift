import SharedKit
import SwiftUI

enum Theme {
	static let carpet = Color(hex: 0x1F4D57)
	static let carpetDeep = Color(hex: 0x173C44)
	static let brass = Color(hex: 0xE0BC62)
	static let brassInk = Color(hex: 0x4A3518)
	static let coral = Color(hex: 0xE4574A)
	static let mint = Color(hex: 0x74E0B0)
	static let amber = Color(hex: 0xF4B23E)
	static let paper = Color(hex: 0xF6F1E6)
}

extension Font {
	static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
		.system(style, design: .rounded, weight: weight)
	}
}

enum PhoneFormat {
	/// "+14155550123" → "+1 415 555 0123", "+4915112345678" → "+49 151 12345678". Display only.
	static func pretty(_ e164: String?) -> String {
		guard let e164, e164.hasPrefix("+") else { return e164 ?? "Hidden number" }
		let digits = Array(e164.dropFirst())
		if digits.first == "1", digits.count == 11 {
			let d = String(digits)
			return "+1 \(d.dropFirst().prefix(3)) \(d.dropFirst(4).prefix(3)) \(d.dropFirst(7))"
		}
		if digits.starts(with: ["4", "9"]), digits.count > 5 {
			let d = String(digits)
			return "+49 \(d.dropFirst(2).prefix(3)) \(d.dropFirst(5))"
		}
		return e164
	}

	static func length(_ seconds: TimeInterval) -> String {
		let total = Int(seconds.rounded())
		return String(format: "%d:%02d", total / 60, total % 60)
	}
}
