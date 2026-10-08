import Foundation

/// How a deskmate looks. Indices into the pixel-art palettes in OfficeKit.
public struct Look: Codable, Hashable, Sendable {
	public var skin: Int
	public var hair: Int
	public var hairColor: Int
	public var shirt: Int
	public var accessory: Int

	public init(skin: Int = 0, hair: Int = 0, hairColor: Int = 0, shirt: Int = 0, accessory: Int = 0) {
		self.skin = skin
		self.hair = hair
		self.hairColor = hairColor
		self.shirt = shirt
		self.accessory = accessory
	}

	public static func random() -> Look {
		Look(
			skin: Int.random(in: 0..<5),
			hair: Int.random(in: 0..<6),
			hairColor: Int.random(in: 0..<7),
			shirt: Int.random(in: 0..<8),
			accessory: Int.random(in: 0..<2)
		)
	}

	enum CodingKeys: String, CodingKey {
		case skin, hair, shirt, accessory
		case hairColor = "hair_color"
	}

	// `look` is jsonb with a `{}` default, so every field may be missing.
	public init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		skin = try c.decodeIfPresent(Int.self, forKey: .skin) ?? 0
		hair = try c.decodeIfPresent(Int.self, forKey: .hair) ?? 0
		hairColor = try c.decodeIfPresent(Int.self, forKey: .hairColor) ?? 0
		shirt = try c.decodeIfPresent(Int.self, forKey: .shirt) ?? 0
		accessory = try c.decodeIfPresent(Int.self, forKey: .accessory) ?? 0
	}
}

public enum DeskLanguage: String, Codable, CaseIterable, Sendable, Identifiable {
	case en, de, multi

	public var id: String { rawValue }

	public var label: String {
		switch self {
			case .en: "English"
			case .de: "German"
			case .multi: "Caller's language"
		}
	}
}

public struct Desk: Codable, Identifiable, Hashable, Sendable {
	public let id: UUID
	public var seat: Int
	public var name: String
	public var role: String
	public var instructions: String
	public var greeting: String
	public var language: DeskLanguage
	public var voice: String
	public var look: Look

	enum CodingKeys: String, CodingKey {
		case id, seat, name, role, instructions, greeting, language, voice, look
	}
}

public enum LineProvider: String, Codable, Sendable {
	case livekit
	case sipTrunk = "sip_trunk"
}

public struct PhoneLine: Codable, Identifiable, Hashable, Sendable {
	public let id: UUID
	public var deskID: UUID?
	public let e164: String
	public let provider: LineProvider
	public let locality: String?
	public let canInbound: Bool
	public let canOutbound: Bool

	enum CodingKeys: String, CodingKey {
		case id, e164, provider, locality
		case deskID = "desk_id"
		case canInbound = "can_inbound"
		case canOutbound = "can_outbound"
	}

	public var capabilityLabel: String {
		canOutbound ? "Calls in and out" : "Takes calls only"
	}
}

public enum CallDirection: String, Codable, Sendable {
	case inbound, outbound, web
}

public enum CallStatus: String, Codable, Sendable {
	case ringing, dialing, active, human, ended, missed, failed

	public var isLive: Bool {
		switch self {
			case .ringing, .dialing, .active, .human: true
			case .ended, .missed, .failed: false
		}
	}
}

public struct TranscriptLine: Codable, Hashable, Sendable {
	public let role: String
	public let text: String

	public var isAgent: Bool { role == "assistant" }
}

public struct TakenMessage: Codable, Hashable, Sendable {
	public let callerName: String
	public let callbackNumber: String?
	public let text: String

	enum CodingKeys: String, CodingKey {
		case text
		case callerName = "caller_name"
		case callbackNumber = "callback_number"
	}
}

public struct Call: Codable, Identifiable, Hashable, Sendable {
	public let id: UUID
	public let deskID: UUID?
	public let lineID: UUID?
	public let direction: CallDirection
	public let remoteNumber: String?
	public let roomName: String
	public let status: CallStatus
	public let agentState: String?
	public let transcript: [TranscriptLine]
	public let message: TakenMessage?
	public let error: String?
	public let startedAt: Date
	public let answeredAt: Date?
	public let endedAt: Date?

	enum CodingKeys: String, CodingKey {
		case id, direction, status, transcript, message, error
		case deskID = "desk_id"
		case lineID = "line_id"
		case remoteNumber = "remote_number"
		case roomName = "room_name"
		case agentState = "agent_state"
		case startedAt = "started_at"
		case answeredAt = "answered_at"
		case endedAt = "ended_at"
	}

	public var isLive: Bool { status.isLive }

	public var duration: TimeInterval? {
		guard let answeredAt else { return nil }
		return (endedAt ?? .now).timeIntervalSince(answeredAt)
	}
}

/// A number you can put on a desk, from LiveKit (US, inbound) or the studio's SIP trunk pool.
public struct AvailableNumber: Decodable, Identifiable, Hashable, Sendable {
	public let e164: String
	public let locality: String?
	public let region: String?
	public let provider: LineProvider
	public let canOutbound: Bool

	public var id: String { e164 }

	enum CodingKeys: String, CodingKey {
		case e164, locality, region, provider
		case canOutbound = "can_outbound"
	}

	public var place: String? {
		[locality, region].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: ", ").nilIfEmpty
	}
}

/// LiveKit connection details for joining a call room from the app.
public struct CallCredentials: Decodable, Sendable {
	public let serverURL: URL
	public let participantToken: String
	public let roomName: String
	public let callID: UUID

	enum CodingKeys: String, CodingKey {
		case serverURL = "server_url"
		case participantToken = "participant_token"
		case roomName = "room_name"
		case callID = "call_id"
	}
}

public enum VoicePreset: CaseIterable, Identifiable {
	case jacqueline, blake, robyn, daniela, house

	public var id: String { model }

	/// LiveKit Inference TTS model string. IDs from LiveKit's Cartesia voice list.
	public var model: String {
		switch self {
			case .jacqueline: "cartesia/sonic-3:9626c31c-bec5-4cca-baa8-f8ba9e84c8bc"
			case .blake: "cartesia/sonic-3:a167e0f3-df7e-4d52-a9c3-f949145efdab"
			case .robyn: "cartesia/sonic-3:f31cc6a7-c1e8-4764-980c-60a361443dd1"
			case .daniela: "cartesia/sonic-3:5c5ad5e7-1020-476b-8b91-fdcbe9cc313c"
			case .house: "cartesia/sonic-3"
		}
	}

	public var name: String {
		switch self {
			case .jacqueline: "Jacqueline"
			case .blake: "Blake"
			case .robyn: "Robyn"
			case .daniela: "Daniela"
			case .house: "House voice"
		}
	}

	public var detail: String {
		switch self {
			case .jacqueline: "Confident, young, American"
			case .blake: "Energetic, American"
			case .robyn: "Calm, mature, Australian"
			case .daniela: "Calm and warm, Mexican"
			case .house: "Cartesia's default for the desk's language"
		}
	}

	public static func matching(_ model: String) -> VoicePreset? {
		allCases.first { $0.model == model }
	}
}

extension String {
	var nilIfEmpty: String? { isEmpty ? nil : self }
}
