import AnalyticsKit
import SharedKit
import SupabaseKit
import SwiftUI

/// What the office is showing in a sheet or full-screen cover.
enum OfficeRoute: Identifiable, Hashable {
	case hire(seat: Int)
	case desk(UUID)
	case lines

	var id: String {
		switch self {
			case .hire(let seat): "hire-\(seat)"
			case .desk(let id): "desk-\(id)"
			case .lines: "lines"
		}
	}
}

enum CallRoute: Identifiable, Hashable {
	case talk(deskID: UUID)
	case listen(callID: UUID)

	var id: String {
		switch self {
			case .talk(let id): "talk-\(id)"
			case .listen(let id): "listen-\(id)"
		}
	}
}

public struct OfficeView: View {
	@EnvironmentObject private var db: DB
	@EnvironmentObject private var store: OfficeStore

	@State private var route: OfficeRoute?
	@State private var callRoute: CallRoute?

	public init() {}

	public var body: some View {
		SignedInGate(prompt: "Sign in to open your office") {
			officeFloor
		}
		.task(id: db.authState == .signedIn) {
			guard db.authState == .signedIn else {
				await store.disconnectRealtime()
				store.reset()
				return
			}
			await store.connectRealtime()
			await store.load()
		}
		.captureViewActivity(as: "OfficeView")
	}

	private var officeFloor: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 0) {
					OfficeSceneView(seats: seats) { seat in
						Haptics.impact(style: .light)
						if let desk = store.desk(atSeat: seat) {
							route = .desk(desk.id)
						} else {
							route = .hire(seat: seat)
						}
					}

					FloorNotes(callRoute: $callRoute, route: $route)
						.padding(.horizontal, 20)
						.padding(.top, 20)
						.padding(.bottom, 32)
				}
			}
			.scrollBounceBehavior(.basedOnSize)
			.background(Theme.carpet.ignoresSafeArea())
			.navigationTitle("Office")
			.navigationBarTitleDisplayMode(.inline)
			.toolbarBackground(Theme.carpetDeep, for: .navigationBar)
			.toolbarBackground(.visible, for: .navigationBar)
			.toolbarColorScheme(.dark, for: .navigationBar)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						route = .lines
					} label: {
						Label("Phone lines", systemImage: "phone.connection")
					}
					.tint(Theme.paper)
				}
			}
			.refreshable { await store.load() }
		}
		.sheet(item: $route) { route in
			switch route {
				case .hire(let seat):
					HireSheet(seat: seat) { desk in
						self.route = .desk(desk.id)
					}
				case .desk(let id):
					DeskSheet(deskID: id, callRoute: $callRoute)
				case .lines:
					LinesSheet()
			}
		}
		.fullScreenCover(item: $callRoute) { route in
			CallScreen(route: route)
		}
	}

	private var seats: [DeskSnapshot?] {
		(0..<OfficeStore.seatCount).map { seat in
			store.desk(atSeat: seat).map { desk in
				DeskSnapshot(
					name: desk.name,
					look: desk.look,
					hasLine: store.line(for: desk) != nil,
					activity: DeskActivity(call: store.liveCall(for: desk))
				)
			}
		}
	}
}

/// Plain-language status under the office: who's on a call, or what to do first.
private struct FloorNotes: View {
	@EnvironmentObject private var office: OfficeStore
	@Binding var callRoute: CallRoute?
	@Binding var route: OfficeRoute?

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			if !office.hasLoaded {
				ProgressView()
					.tint(Theme.paper)
					.frame(maxWidth: .infinity)
			} else if office.liveCalls.isEmpty {
				Text(hint)
					.font(.rounded(.callout))
					.foregroundStyle(Theme.paper.opacity(0.8))
					.fixedSize(horizontal: false, vertical: true)
			} else {
				ForEach(office.liveCalls) { call in
					LiveCallRow(call: call) {
						callRoute = .listen(callID: call.id)
					}
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var hint: String {
		if office.desks.isEmpty {
			return "Tap an empty desk to hire your first deskmate."
		}
		if office.lines.isEmpty {
			return "Your deskmates are ready. Tap one to talk to them, or give them a phone so they can take real calls."
		}
		return "Quiet for now. When someone calls one of your numbers, you'll see the phone ring here."
	}
}

struct LiveCallRow: View {
	@EnvironmentObject private var office: OfficeStore
	let call: Call
	let onListen: () -> Void

	var body: some View {
		HStack(spacing: 12) {
			if let desk = office.desk(id: call.deskID) {
				PortraitView(look: desk.look, activity: DeskActivity(call: call), background: Theme.carpetDeep)
					.frame(width: 44, height: 44)
					.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
			}
			VStack(alignment: .leading, spacing: 2) {
				Text(CallCopy.headline(for: call, deskName: office.desk(id: call.deskID)?.name))
					.font(.rounded(.subheadline, weight: .semibold))
					.foregroundStyle(Theme.paper)
				Text(CallCopy.lastLine(for: call))
					.font(.rounded(.footnote))
					.foregroundStyle(Theme.paper.opacity(0.7))
					.lineLimit(1)
			}
			Spacer(minLength: 8)
			if call.direction != .web {
				Button("Listen", action: onListen)
					.font(.rounded(.subheadline, weight: .semibold))
					.buttonStyle(.borderedProminent)
					.tint(Theme.mint)
					.foregroundStyle(Theme.carpetDeep)
			}
		}
		.padding(12)
		.background(Theme.carpetDeep, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
	}
}

enum CallCopy {
	static func headline(for call: Call, deskName: String?) -> String {
		let name = deskName ?? "A deskmate"
		let other = PhoneFormat.pretty(call.remoteNumber)
		switch (call.status, call.direction) {
			case (.dialing, _): return "\(name) is dialing \(other)"
			case (.ringing, .web): return "\(name) is picking up"
			case (.ringing, _): return "\(name)'s phone is ringing"
			case (.human, _): return "You're on the line with \(other)"
			case (_, .web): return "\(name) is talking to you"
			case (_, .inbound): return "\(name) is talking to \(other)"
			case (_, .outbound): return "\(name) called \(other)"
		}
	}

	static func lastLine(for call: Call) -> String {
		guard let line = call.transcript.last else { return "Connecting…" }
		return line.isAgent ? line.text : "“\(line.text)”"
	}

	static func summary(for call: Call) -> String {
		switch call.status {
			case .missed: return call.direction == .outbound ? "No answer" : "Missed"
			case .failed: return call.error.map { "Didn't connect: \($0)" } ?? "Didn't connect"
			default:
				if let duration = call.duration { return PhoneFormat.length(duration) }
				return call.status.isLive ? "Live now" : "Ended"
		}
	}
}
