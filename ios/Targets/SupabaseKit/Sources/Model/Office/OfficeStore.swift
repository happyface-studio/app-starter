import AnalyticsKit
import Foundation
import SharedKit
import Supabase
import SwiftUI

public struct OfficeError: LocalizedError {
	public let message: String
	public var errorDescription: String? { message }
}

/// Desks, phone lines and calls for the signed-in user, kept live with Supabase Realtime.
@MainActor
public final class OfficeStore: ObservableObject {

	public static let seatCount = 6

	@Published public private(set) var desks: [Desk] = []
	@Published public private(set) var lines: [PhoneLine] = []
	@Published public private(set) var calls: [Call] = []
	@Published public private(set) var hasLoaded = false

	private let db: DB
	private var channel: RealtimeChannelV2?
	private var realtimeTasks: [Task<Void, Never>] = []

	public init(db: DB) {
		self.db = db
	}

	private var client: SupabaseClient { db._db }

	// MARK: - Lookups

	public func desk(atSeat seat: Int) -> Desk? {
		desks.first { $0.seat == seat }
	}

	public func desk(id: UUID?) -> Desk? {
		guard let id else { return nil }
		return desks.first { $0.id == id }
	}

	public func line(for desk: Desk) -> PhoneLine? {
		lines.first { $0.deskID == desk.id }
	}

	public func liveCall(for desk: Desk) -> Call? {
		calls.first { $0.deskID == desk.id && $0.isLive }
	}

	public var liveCalls: [Call] {
		calls.filter(\.isLive)
	}

	public var unpluggedLines: [PhoneLine] {
		lines.filter { $0.deskID == nil }
	}

	public var nextFreeSeat: Int? {
		(0..<Self.seatCount).first { desk(atSeat: $0) == nil }
	}

	// MARK: - Loading

	public func load() async {
		let client = self.client
		do {
			async let desks: [Desk] = client.from("desks").select().order("seat").execute().value
			async let lines: [PhoneLine] = client.from("phone_lines").select().order("created_at").execute().value
			async let calls: [Call] = client.from("calls").select().order("started_at", ascending: false)
				.limit(60).execute().value
			(self.desks, self.lines, self.calls) = try await (desks, lines, calls)
			hasLoaded = true
		} catch {
			Analytics.capture(.error, id: "office_load", longDescription: "\(error)", source: .db)
			showError(error)
		}
	}

	public func reset() {
		desks = []
		lines = []
		calls = []
		hasLoaded = false
	}

	public func connectRealtime() async {
		guard channel == nil, let userID = db.currentUser?.id.uuidString.lowercased() else { return }
		let channel = client.channel("office-\(userID)")
		let callChanges = channel.postgresChange(
			AnyAction.self, schema: "public", table: "calls", filter: "user_id=eq.\(userID)")
		let lineChanges = channel.postgresChange(
			AnyAction.self, schema: "public", table: "phone_lines", filter: "user_id=eq.\(userID)")
		await channel.subscribe()
		self.channel = channel

		realtimeTasks = [
			Task { [weak self] in
				for await change in callChanges {
					self?.apply(callChange: change)
				}
			},
			Task { [weak self] in
				for await change in lineChanges {
					self?.apply(lineChange: change)
				}
			},
		]
	}

	public func disconnectRealtime() async {
		realtimeTasks.forEach { $0.cancel() }
		realtimeTasks = []
		if let channel {
			await client.removeChannel(channel)
		}
		channel = nil
	}

	private func apply(callChange change: AnyAction) {
		switch change {
			case .insert(let action):
				guard let call = try? action.decodeRecord(as: Call.self, decoder: Self.realtimeDecoder) else { return }
				calls.removeAll { $0.id == call.id }
				calls.insert(call, at: 0)
			case .update(let action):
				guard let call = try? action.decodeRecord(as: Call.self, decoder: Self.realtimeDecoder) else { return }
				if let index = calls.firstIndex(where: { $0.id == call.id }) {
					calls[index] = call
				} else {
					calls.insert(call, at: 0)
				}
			case .delete(let action):
				guard let old = try? action.decodeOldRecord(as: RowID.self, decoder: Self.realtimeDecoder) else { return }
				calls.removeAll { $0.id == old.id }
		}
	}

	private func apply(lineChange change: AnyAction) {
		func upsert(_ line: PhoneLine?) {
			guard let line else { return }
			if let index = lines.firstIndex(where: { $0.id == line.id }) {
				lines[index] = line
			} else {
				lines.append(line)
			}
		}
		switch change {
			case .insert(let action):
				upsert(try? action.decodeRecord(as: PhoneLine.self, decoder: Self.realtimeDecoder))
			case .update(let action):
				upsert(try? action.decodeRecord(as: PhoneLine.self, decoder: Self.realtimeDecoder))
			case .delete(let action):
				guard let old = try? action.decodeOldRecord(as: RowID.self, decoder: Self.realtimeDecoder) else { return }
				lines.removeAll { $0.id == old.id }
		}
	}

	// MARK: - Desks

	private static let starterNames = ["Paula", "Otto", "Mia", "Kofi", "Lena", "Ravi", "Noor", "Jules"]

	public func hire(seat: Int, look: Look = .random()) async throws -> Desk {
		let taken = Set(desks.map(\.name))
		let name = Self.starterNames.first { !taken.contains($0) } ?? "Deskmate"
		let german = Locale.current.language.languageCode?.identifier == "de"

		struct NewDesk: Encodable {
			let seat: Int
			let name: String
			let role: String
			let greeting: String
			let language: DeskLanguage
			let voice: String
			let look: Look
		}
		let desk: Desk = try await perform("hire_desk") {
			try await self.client.from("desks")
				.insert(
					NewDesk(
						seat: seat,
						name: name,
						role: german ? "Empfang" : "Receptionist",
						greeting: german
							? "Hallo, hier ist \(name). Wie kann ich helfen?"
							: "Hi, this is \(name). How can I help?",
						language: german ? .de : .en,
						voice: VoicePreset.house.model,
						look: look
					)
				)
				.select()
				.single()
				.execute()
				.value
		}
		desks.append(desk)
		desks.sort { $0.seat < $1.seat }
		return desk
	}

	public func save(_ desk: Desk) async throws {
		struct DeskUpdate: Encodable {
			let name: String
			let role: String
			let instructions: String
			let greeting: String
			let language: DeskLanguage
			let voice: String
			let look: Look
		}
		let update = DeskUpdate(
			name: desk.name, role: desk.role, instructions: desk.instructions, greeting: desk.greeting,
			language: desk.language, voice: desk.voice, look: desk.look)
		try await perform("save_desk") {
			try await self.client.from("desks").update(update).eq("id", value: desk.id).execute()
		}
		if let index = desks.firstIndex(where: { $0.id == desk.id }) {
			desks[index] = desk
		}
	}

	public func remove(_ desk: Desk) async throws {
		try await perform("remove_desk") {
			try await self.client.from("desks").delete().eq("id", value: desk.id).execute()
		}
		desks.removeAll { $0.id == desk.id }
		for index in lines.indices where lines[index].deskID == desk.id {
			lines[index].deskID = nil
		}
	}

	// MARK: - Phone lines

	public func searchNumbers(areaCode: String?) async throws -> [AvailableNumber] {
		struct Body: Encodable {
			let action = "search"
			let country_code = "US"
			let area_code: String?
		}
		let trimmed = areaCode?.trimmingCharacters(in: .whitespaces)
		let result: NumbersResponse = try await invoke(
			"phone-numbers", Body(area_code: trimmed?.nilIfEmpty))
		return result.numbers
	}

	public func poolNumbers() async throws -> [AvailableNumber] {
		struct Body: Encodable { let action = "pool" }
		let result: NumbersResponse = try await invoke("phone-numbers", Body())
		return result.numbers
	}

	public func take(_ number: AvailableNumber, for desk: Desk?) async throws {
		struct Body: Encodable {
			let action: String
			let e164: String
			let desk_id: UUID?
		}
		let body = Body(
			action: number.provider == .livekit ? "rent" : "claim", e164: number.e164, desk_id: desk?.id)
		let result: LineResponse = try await invoke("phone-numbers", body)
		lines.removeAll { $0.id == result.line.id }
		for index in lines.indices where lines[index].deskID == result.line.deskID && result.line.deskID != nil {
			lines[index].deskID = nil
		}
		lines.append(result.line)
	}

	public func plug(_ line: PhoneLine, into desk: Desk?) async throws {
		struct Params: Encodable {
			let pLine: UUID
			let pDesk: UUID?
			enum CodingKeys: String, CodingKey {
				case pLine = "p_line"
				case pDesk = "p_desk"
			}
			func encode(to encoder: Encoder) throws {
				var c = encoder.container(keyedBy: CodingKeys.self)
				try c.encode(pLine, forKey: .pLine)
				try c.encode(pDesk, forKey: .pDesk)  // explicit null: the SQL function takes both args
			}
		}
		try await perform("plug_line") {
			try await self.client.rpc("plug_line", params: Params(pLine: line.id, pDesk: desk?.id)).execute()
		}
		for index in lines.indices {
			if lines[index].id == line.id {
				lines[index].deskID = desk?.id
			} else if desk != nil, lines[index].deskID == desk?.id {
				lines[index].deskID = nil
			}
		}
	}

	public func release(_ line: PhoneLine) async throws {
		struct Body: Encodable {
			let action = "release"
			let line_id: UUID
		}
		let _: OK = try await invoke("phone-numbers", Body(line_id: line.id))
		lines.removeAll { $0.id == line.id }
	}

	// MARK: - Calls

	public func credentials(talkingTo desk: Desk) async throws -> CallCredentials {
		struct Body: Encodable {
			let mode = "talk"
			let desk_id: UUID
		}
		return try await invoke("session-token", Body(desk_id: desk.id))
	}

	public func credentials(listeningTo call: Call) async throws -> CallCredentials {
		struct Body: Encodable {
			let mode = "listen"
			let call_id: UUID
		}
		return try await invoke("session-token", Body(call_id: call.id))
	}

	@discardableResult
	public func placeCall(from desk: Desk, to number: String, brief: String) async throws -> UUID {
		struct Body: Encodable {
			let desk_id: UUID
			let to: String
			let brief: String
		}
		struct Response: Decodable { let call_id: UUID }
		let response: Response = try await invoke(
			"place-call", Body(desk_id: desk.id, to: number, brief: brief))
		return response.call_id
	}

	public func hangUp(_ call: Call) async throws {
		struct Body: Encodable { let call_id: UUID }
		let _: OK = try await invoke("end-call", Body(call_id: call.id))
	}

	public func delete(_ call: Call) async throws {
		try await perform("delete_call") {
			try await self.client.from("calls").delete().eq("id", value: call.id).execute()
		}
		calls.removeAll { $0.id == call.id }
	}

	// MARK: - Plumbing

	private struct RowID: Decodable { let id: UUID }
	private struct OK: Decodable {}
	private struct NumbersResponse: Decodable { let numbers: [AvailableNumber] }
	private struct LineResponse: Decodable { let line: PhoneLine }
	private struct ErrorBody: Decodable { let error: String }

	private func invoke<Response: Decodable>(_ function: String, _ body: some Encodable) async throws -> Response {
		try await perform(function) {
			try await self.client.functions.invoke(function, options: FunctionInvokeOptions(body: body))
		}
	}

	private func perform<T>(_ id: String, _ work: () async throws -> T) async throws -> T {
		do {
			let result = try await work()
			Analytics.capture(.success, id: id, source: .db)
			return result
		} catch {
			Analytics.capture(.error, id: id, longDescription: "\(error)", source: .db)
			throw Self.readable(error)
		}
	}

	private static func readable(_ error: Error) -> Error {
		if case let FunctionsError.httpError(_, data) = error,
			let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
		{
			return OfficeError(message: body.error)
		}
		return error
	}

	private func showError(_ error: Error) {
		showInAppNotification(
			.error,
			content: .init(
				title: "Couldn't load your office",
				message: LocalizedStringKey(error.localizedDescription)))
	}

	/// Realtime payloads carry Postgres timestamps with microseconds, which ISO8601DateFormatter
	/// doesn't reliably parse, so trim to milliseconds first.
	static let realtimeDecoder: JSONDecoder = {
		let decoder = JSONDecoder()
		let withFraction = ISO8601DateFormatter()
		withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		let plain = ISO8601DateFormatter()
		plain.formatOptions = [.withInternetDateTime]
		decoder.dateDecodingStrategy = .custom { decoder in
			let raw = try decoder.singleValueContainer().decode(String.self)
			let normalized = raw.replacingOccurrences(
				of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression)
			if let date = withFraction.date(from: normalized) ?? plain.date(from: normalized) {
				return date
			}
			throw DecodingError.dataCorrupted(
				.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(raw)"))
		}
		return decoder
	}()
}
