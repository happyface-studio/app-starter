// Generated from the Deskmates pixel-art source (design.py). Edit there, then regenerate.
// swiftlint:disable all

import Foundation

enum PixelArt {
	static let fixed: [Character: UInt32] = [
		"k": 0x2B1F2E,
		"e": 0x2B1F2E,
		"m": 0x7A2E35,
		"r": 0xC9474F,
		"b": 0xF2A3A0,
		"g": 0x3C4150,
		"G": 0x7D8496,
		"l": 0x2B1F2E,
		"w": 0xF6F1E6,
		"p": 0xE4574A,
		"P": 0xB23E33,
		"o": 0x5C5357,
		"u": 0xD9CFB8,
		"U": 0xB4A98F,
		"y": 0xF4D35E,
		"Y": 0xD9B43E,
		"d": 0xC98B3F,
		"D": 0x9C6A2C,
		"q": 0x7A5020,
		"n": 0xE0BC62,
		"N": 0xA88536,
		"t": 0x4A3518,
		"f": 0x7083B8,
		"F": 0x5A6C9E,
		"T": 0xC9CBD3,
		"a": 0x2D3557,
		"A": 0x3E4870,
		"v": 0x5FA86A,
		"V": 0x3F7F4C,
		"z": 0xB5653A,
		"Z": 0x8E4A28,
		"M": 0xF6F1E6,
		"x": 0x8C6248,
	]
	static let skins: [(UInt32, UInt32)] = [
		(0xF6D2B4, 0xE2AE8C),
		(0xEDB88B, 0xD2996B),
		(0xC98E5E, 0xAA7144),
		(0x9C6440, 0x7E4C2E),
		(0x6E4428, 0x55331D),
	]
	static let hairColors: [(UInt32, UInt32)] = [
		(0x2E2633, 0x1C1720),
		(0x6B4127, 0x4E2E1B),
		(0xB14D2E, 0x86371F),
		(0xE7C76B, 0xC6A246),
		(0xBDBAC4, 0x918E9A),
		(0x5476D8, 0x3A57AE),
		(0xEA82AE, 0xC65F8D),
	]
	static let shirts: [(UInt32, UInt32)] = [
		(0xE8A33D, 0xC1822A),
		(0x2F9C90, 0x22766C),
		(0x9C88D8, 0x7A66B6),
		(0xEEEBE4, 0xC8C4BA),
		(0x5BA661, 0x438548),
		(0x3D4F86, 0x2B3A66),
		(0xE4574A, 0xB23E33),
		(0x3B3641, 0x27232C),
	]

	static let carpet: UInt32 = 0x1F4D57
	static let carpetDot: UInt32 = 0x25596A
	static let carpetDark: UInt32 = 0x1A424B
	static let wall: UInt32 = 0xA7BFB0
	static let wallShade: UInt32 = 0x93AD9D
	static let baseboard: UInt32 = 0x6B5A4A
	static let amber: UInt32 = 0xF4B23E
	static let mint: UInt32 = 0x74E0B0
	static let sky: [String: (UInt32, UInt32)] = [
		"day": (0x8ED3F2, 0xBFE8FA),
		"dusk": (0xF2A35E, 0xF6C98A),
		"night": (0x1E2B57, 0x2E3E73),
	]

	static let body = Sprite([
			"................",
			"................",
			"....kkkkkkkk....",
			"...ksssssssSk...",
			"...ksssssssSk...",
			"...ksssssssSk...",
			"..kSsssssssSSk..",
			"...ksssssssSk...",
			"...ksssssssSk...",
			"...ksssssssSk...",
			"....kSsssssk....",
			".....kkkkkk.....",
			"......kSSk......",
			"...kkkcSScckk...",
			"..kccccSSccccCk.",
			".kcccccccccccCk.",
			".kCcccccccccCCk.",
			".kCcccccccccCCk.",
		])
	static let face = Sprite([
			"................",
			"................",
			"................",
			"................",
			"................",
			".....e....e.....",
			".....e....e.....",
			"................",
			"....b......b....",
			".......mm.......",
			"................",
			"................",
		])
	static let faceBlink = Sprite([
			"................",
			"................",
			"................",
			"................",
			"................",
			".....s....s.....",
			".....e....e.....",
			"................",
			"....b......b....",
			".......mm.......",
			"................",
			"................",
		])
	static let mouthOpen = Sprite([
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"................",
			"......kmmk......",
			".......rr.......",
			"................",
		])
	static let phone = Sprite([
			"..kkkkkk..",
			".kppppppk.",
			"kpPk..kPpk",
			"kkppppppkk",
			"kpwpwpwopk",
			"kPPPPPPPPk",
			".kkkkkkkk.",
		])
	static let phoneDead = Sprite([
			"..kkkkkk..",
			".kUUUUUUk.",
			"kUDk..kDUk",
			"kkUUUUUUkk",
			"kUwUwUwoUk",
			"kDDDDDDDDk",
			".kkkkkkkk.",
		])
	static let monitor = Sprite([
			".kkkkkkkk.",
			"kuuuuuuuuk",
			"kuUUUUUuuk",
			"kuuuuuuuuk",
			"kuUUUUUuuk",
			"kuuuuuyyuk",
			"kuuuuuyYuk",
			".kkkkkkkk.",
			"....kk....",
			"..kkkkkk..",
		])
	static let mug = Sprite([
			"kkkk",
			"kxxk",
			"kMMk",
			"kkkk",
		])
	static let plant = Sprite([
			"...v.v...",
			"..vVvVv..",
			".vVvvvVv.",
			"..vvVvv..",
			"...kkk...",
			"..kzzzk..",
			"..kzZzk..",
			"...kkk...",
		])
	static let chair = Sprite([
			"..kkkkkkkkkkkkkk..",
			".kaAAAAAAAAAAAAak.",
			"kaAaaaaaaaaaaaaAak",
			"kaaaaaaaaaaaaaaaak",
			"kaaaaaaaaaaaaaaaak",
			"kaaaaaaaaaaaaaaaak",
			"kaaaaaaaaaaaaaaaak",
			"kaaaaaaaaaaaaaaaak",
		])
	static let steam = [
		Sprite([
			".w..",
			"w...",
			".w..",
		]),
		Sprite([
			"..w.",
			".w..",
			"..w.",
		]),
	]

	/// Same order as `Look.hair` in the database.
	static let hairStyles: [Sprite] = [
		Sprite([
			"................",
			".....kkkkkk.....",
			"....khhhhhhk....",
			"...khhhhhhhHk...",
			"...khhhhHhhhk...",
			"...kh......hk...",
		]),  // short
		Sprite([
			"................",
			".....kkkkkk.....",
			"....khhhhhhk....",
			"...khhhhhhhHk...",
			"..khhhHhhhhhHk..",
			"..khh......hHk..",
			"..khh......hHk..",
			"..khh......hHk..",
			"..khh......hHk..",
			"..kkh......hkk..",
			"...kk......kk...",
		]),  // bob
		Sprite([
			"......kkkk......",
			".....khhHhk.....",
			"....kkhhhhkk....",
			"...khhhhhhhHk...",
			"...khHhhhhhhk...",
			"...kh......hk...",
		]),  // bun
		Sprite([
			"....kkkkkkkk....",
			"...khhhHhhhhk...",
			"..khhHhhhhHhhk..",
			".khhhhhhhhhhHhk.",
			".khHhhhhhhhhhHk.",
			".khh........hHk.",
			".khh........hHk.",
			".kkh........hkk.",
			"..kk........kk..",
		]),  // curly
		Sprite([
			"................",
			"................",
			"....kkkkkkkk....",
			"...khHhHhHhHk...",
		]),  // buzz
		Sprite([
			"................",
			".....kkkkkk.....",
			"....khhhhhhk....",
			"...khhhhhhhHk...",
			"..khhhhHhhhhHk..",
			"..khh......hHk..",
			"..khh......hHk..",
			"..khh......hHk..",
			"..khh......hHk..",
			"..khh......hHk..",
			"..khh......hHk..",
			"..khh......hHk..",
			"..khk......khk..",
			"..kk........kk..",
		]),  // long
	]
	static let hairStyleNames = ["Short", "Bob", "Bun", "Curly", "Buzz", "Long"]
	/// Same order as `Look.accessory` in the database.
	static let accessories: [Sprite] = [
		Sprite([
			"................",
			"................",
			"................",
			"................",
			"................",
			"..kk........kk..",
			".kGgk......kgGk.",
			".kggk......kggk.",
			"..kk........kk..",
			"...gg...........",
			"....ggG.........",
		]),  // headset
		Sprite([
			"................",
			"................",
			"................",
			"................",
			"................",
			"....lll..lll....",
			"....l.llll.l....",
			"....lll..lll....",
		]),  // glasses
		Sprite([
			".",
		]),  // none
		Sprite([
			"..........kk.kk.",
			".........kpkkpk.",
			"..........kk.kk.",
		]),  // bow
	]
	static let accessoryNames = ["Headset", "Glasses", "None", "Bow"]

	static let font: [Character: [String]] = [
		"A": ["###", "#.#", "###", "#.#", "#.#"],
		"B": ["##.", "#.#", "##.", "#.#", "##."],
		"C": ["###", "#..", "#..", "#..", "###"],
		"D": ["##.", "#.#", "#.#", "#.#", "##."],
		"E": ["###", "#..", "##.", "#..", "###"],
		"F": ["###", "#..", "##.", "#..", "#.."],
		"G": ["###", "#..", "#.#", "#.#", "###"],
		"H": ["#.#", "#.#", "###", "#.#", "#.#"],
		"I": ["###", ".#.", ".#.", ".#.", "###"],
		"J": ["..#", "..#", "..#", "#.#", "###"],
		"K": ["#.#", "#.#", "##.", "#.#", "#.#"],
		"L": ["#..", "#..", "#..", "#..", "###"],
		"M": ["#.#", "###", "###", "#.#", "#.#"],
		"N": ["##.", "#.#", "#.#", "#.#", "#.#"],
		"O": ["###", "#.#", "#.#", "#.#", "###"],
		"P": ["###", "#.#", "###", "#..", "#.."],
		"Q": ["###", "#.#", "#.#", "###", "..#"],
		"R": ["##.", "#.#", "##.", "#.#", "#.#"],
		"S": ["###", "#..", "###", "..#", "###"],
		"T": ["###", ".#.", ".#.", ".#.", ".#."],
		"U": ["#.#", "#.#", "#.#", "#.#", "###"],
		"V": ["#.#", "#.#", "#.#", "#.#", ".#."],
		"W": ["#.#", "#.#", "###", "###", "#.#"],
		"X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
		"Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
		"Z": ["###", "..#", ".#.", "#..", "###"],
		"0": ["###", "#.#", "#.#", "#.#", "###"],
		"1": [".#.", "##.", ".#.", ".#.", "###"],
		"2": ["##.", "..#", ".#.", "#..", "###"],
		"3": ["##.", "..#", ".#.", "..#", "##."],
		"4": ["#.#", "#.#", "###", "..#", "..#"],
		"5": ["###", "#..", "##.", "..#", "##."],
		"6": [".##", "#..", "###", "#.#", "###"],
		"7": ["###", "..#", ".#.", ".#.", ".#."],
		"8": ["###", "#.#", "###", "#.#", "###"],
		"9": ["###", "#.#", "###", "..#", "##."],
		" ": ["...", "...", "...", "...", "..."],
		"-": ["...", "...", "###", "...", "..."],
		".": ["...", "...", "...", "...", ".#."],
		"!": [".#.", ".#.", ".#.", "...", ".#."],
		"?": ["##.", "..#", ".#.", "...", ".#."],
		"'": [".#.", ".#.", "...", "...", "..."],
		"&": [".#.", "#.#", ".#.", "#.#", ".##"],
	]
	static let fold: [Character: Character] = [
		"Ä": "A",
		"Ö": "O",
		"Ü": "U",
		"ß": "S",
		"É": "E",
		"È": "E",
		"Á": "A",
		"À": "A",
		"Ç": "C",
		"Ñ": "N",
	]

	enum Layout {
		static let sceneWidth = 96
		static let wallHeight = 24
		static let cellWidth = 48
		static let cellHeight = 48
		static let rows = 3
		static let sceneHeight = 168
		static let plateY = 31
		static let plateHeight = 9
		static let nameMax = 8
		static let partition = (x: 2, y: 2, w: 44, h: 16)
		static let deskTop = (x: 3, y: 26, w: 42, h: 4)
		static let deskFront = (x: 4, y: 30, w: 40, h: 11)
		static let chair = (x: 15, y: 17)
		static let character = (x: 16, y: 8)
		static let monitor = (x: 3, y: 17)
		static let phone = (x: 34, y: 19)
		static let mug = (x: 12, y: 23)
		static let bubble = (x: 29, y: 0)
		static let phoneLamp = (x: 7, y: 4)
	}
}
