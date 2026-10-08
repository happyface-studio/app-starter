import LiveKit
import SharedKit
import SupabaseKit
import SwiftUI

/// Full-screen call: talk to a deskmate in the app, or listen in on (and take over) a phone call.
struct CallScreen: View {
	@EnvironmentObject private var office: OfficeStore
	@Environment(\.dismiss) private var dismiss

	let route: CallRoute

	@State private var credentials: CallCredentials?
	@State private var failure: String?

	var body: some View {
		ZStack {
			Theme.carpet.ignoresSafeArea()
			if let credentials {
				switch route {
					case .talk(let deskID):
						if let desk = office.desk(id: deskID) {
							TalkView(desk: desk, credentials: credentials) { dismiss() }
						}
					case .listen(let callID):
						ListenView(callID: callID, credentials: credentials) { dismiss() }
				}
			} else if let failure {
				VStack(spacing: 16) {
					Text("Couldn't connect")
						.font(.rounded(.title2, weight: .bold))
					Text(failure)
						.multilineTextAlignment(.center)
						.foregroundStyle(.secondary)
					Button("Close") { dismiss() }
						.buttonStyle(.secondary())
						.frame(maxWidth: 200)
				}
				.padding(32)
			} else {
				ProgressView("Connecting")
					.tint(Theme.paper)
			}
		}
		.environment(\.colorScheme, .dark)
		.task { await connect() }
	}

	private func connect() async {
		do {
			switch route {
				case .talk(let deskID):
					guard let desk = office.desk(id: deskID) else { return dismiss() }
					credentials = try await office.credentials(talkingTo: desk)
				case .listen(let callID):
					guard let call = office.calls.first(where: { $0.id == callID }) else { return dismiss() }
					credentials = try await office.credentials(listeningTo: call)
			}
		} catch {
			failure = error.localizedDescription
		}
	}
}

// MARK: - Talking to a deskmate in the app

private struct TalkView: View {
	let desk: Desk
	let onEnd: () -> Void

	@StateObject private var session: Session
	@State private var micOn = true

	init(desk: Desk, credentials: CallCredentials, onEnd: @escaping () -> Void) {
		self.desk = desk
		self.onEnd = onEnd
		_session = StateObject(
			wrappedValue: Session(
				tokenSource: LiteralTokenSource(
					serverURL: credentials.serverURL,
					participantToken: credentials.participantToken,
					participantName: "You",
					roomName: credentials.roomName
				)
			))
	}

	var body: some View {
		VStack(spacing: 0) {
			CallHeader(look: desk.look, activity: activity, title: desk.name, status: status)

			Transcript(items: session.messages.map(Self.item))

			HStack(spacing: 24) {
				RoundControl(
					systemImage: micOn ? "mic.fill" : "mic.slash.fill",
					label: micOn ? "Mute" : "Unmute",
					tint: Theme.paper.opacity(0.18)
				) {
					Task {
						micOn.toggle()
						_ = try? await session.room.localParticipant.setMicrophone(enabled: micOn)
					}
				}
				RoundControl(systemImage: "phone.down.fill", label: "End", tint: .red) {
					Task {
						await session.end()
						onEnd()
					}
				}
			}
			.padding(.bottom, 24)
		}
		.task { await session.start() }
		.onDisappear { Task { await session.end() } }
		.sensoryFeedback(.impact(weight: .light), trigger: session.agent.agentState)
	}

	private var activity: DeskActivity {
		switch session.agent.agentState {
			case .speaking: .speaking
			case .thinking: .thinking
			case .listening: .listening
			default: session.agent.isPending ? .ringing : .idle
		}
	}

	private var status: String {
		if let error = session.error { return error.localizedDescription }
		if session.agent.isFinished { return session.agent.error == nil ? "Call ended" : "\(desk.name) didn't pick up" }
		if session.agent.isPending { return "Calling \(desk.name)…" }
		switch session.agent.agentState {
			case .speaking: return "Talking"
			case .thinking: return "Thinking"
			default: return micOn ? "Listening" : "You're muted"
		}
	}

	private static func item(_ message: ReceivedMessage) -> TranscriptItem {
		switch message.content {
			case .agentTranscript(let text):
				return TranscriptItem(id: message.id, text: text, isAgent: true)
			case .userTranscript(let text), .userInput(let text):
				return TranscriptItem(id: message.id, text: text, isAgent: false)
		}
	}
}

// MARK: - Listening in on a phone call

@MainActor
private final class ListenController: ObservableObject {
	enum Phase: Equatable {
		case connecting, listening, onTheLine, failed(String)
	}

	let room = Room()
	@Published var phase: Phase = .connecting
	@Published var micOn = false

	func connect(_ credentials: CallCredentials) async {
		do {
			try await room.connect(url: credentials.serverURL.absoluteString, token: credentials.participantToken)
			phase = .listening
		} catch {
			phase = .failed(error.localizedDescription)
		}
	}

	/// Ask the agent to hand over (it says a short line, then goes quiet), then open the mic.
	func jumpIn() async {
		do {
			if let agent = room.agentParticipant, let identity = agent.identity {
				_ = try await room.localParticipant.performRpc(
					destinationIdentity: identity, method: "deskmates.handoff", payload: "{}")
			}
			try await room.localParticipant.setMicrophone(enabled: true)
			micOn = true
			phase = .onTheLine
		} catch {
			showInAppNotification(
				.error, content: .init(title: "Couldn't jump in", message: LocalizedStringKey(error.localizedDescription)))
		}
	}

	func toggleMic() async {
		micOn.toggle()
		_ = try? await room.localParticipant.setMicrophone(enabled: micOn)
	}

	func leave() async {
		await room.disconnect()
	}
}

private struct ListenView: View {
	@EnvironmentObject private var office: OfficeStore
	@StateObject private var controller = ListenController()

	let callID: UUID
	let credentials: CallCredentials
	let onEnd: () -> Void

	var body: some View {
		let call = office.calls.first { $0.id == callID }
		let desk = office.desk(id: call?.deskID)
		VStack(spacing: 0) {
			CallHeader(
				look: desk?.look ?? Look(),
				activity: DeskActivity(call: call),
				title: PhoneFormat.pretty(call?.remoteNumber),
				status: status(call: call, deskName: desk?.name ?? "Your deskmate")
			)

			Transcript(
				items: (call?.transcript ?? []).enumerated().map { offset, line in
					TranscriptItem(id: "\(offset)", text: line.text, isAgent: line.isAgent)
				})

			VStack(spacing: 16) {
				if controller.phase == .listening {
					Button {
						Task { await controller.jumpIn() }
					} label: {
						Label("Jump in", systemImage: "person.wave.2.fill")
					}
					.buttonStyle(.cta())
					.padding(.horizontal, 32)
				}
				HStack(spacing: 24) {
					if controller.phase == .onTheLine {
						RoundControl(
							systemImage: controller.micOn ? "mic.fill" : "mic.slash.fill",
							label: controller.micOn ? "Mute" : "Unmute",
							tint: Theme.paper.opacity(0.18)
						) {
							Task { await controller.toggleMic() }
						}
					}
					RoundControl(systemImage: "arrow.down.right.and.arrow.up.left", label: "Leave", tint: Theme.paper.opacity(0.18)) {
						Task {
							await controller.leave()
							onEnd()
						}
					}
					RoundControl(systemImage: "phone.down.fill", label: "Hang up", tint: .red) {
						Task {
							if let call { try? await office.hangUp(call) }
							await controller.leave()
							onEnd()
						}
					}
				}
			}
			.padding(.bottom, 24)
		}
		.task { await controller.connect(credentials) }
		.onDisappear { Task { await controller.leave() } }
		.onChange(of: call?.isLive) { _, live in
			guard live == false else { return }
			Task {
				try? await Task.sleep(for: .seconds(1.5))
				await controller.leave()
				onEnd()
			}
		}
	}

	private func status(call: Call?, deskName: String) -> String {
		if case .failed(let message) = controller.phase { return message }
		guard let call, call.isLive else { return "Call ended" }
		switch controller.phase {
			case .connecting: return "Connecting…"
			case .onTheLine: return "You're on the line. \(deskName) stepped back."
			default: return "Listening in. They can't hear you."
		}
	}
}

// MARK: - Shared pieces

private struct CallHeader: View {
	let look: Look
	let activity: DeskActivity
	let title: String
	let status: String

	var body: some View {
		VStack(spacing: 14) {
			PortraitView(look: look, activity: activity, background: Theme.carpetDeep)
				.frame(width: 180, height: 180)
				.clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
			Text(title)
				.font(.rounded(.title, weight: .bold))
				.foregroundStyle(Theme.paper)
			Text(status)
				.font(.rounded(.callout))
				.foregroundStyle(Theme.paper.opacity(0.75))
				.multilineTextAlignment(.center)
				.contentTransition(.opacity)
				.animation(.default, value: status)
		}
		.padding(.top, 40)
		.padding(.horizontal, 24)
	}
}

private struct TranscriptItem: Identifiable {
	let id: String
	let text: String
	let isAgent: Bool
}

private struct Transcript: View {
	let items: [TranscriptItem]

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView {
				LazyVStack(spacing: 8) {
					ForEach(items) { item in
						TranscriptBubble(text: item.text, isAgent: item.isAgent)
							.id(item.id)
					}
				}
				.padding(20)
			}
			.onChange(of: items.last?.text) {
				if let last = items.last?.id {
					withAnimation { proxy.scrollTo(last, anchor: .bottom) }
				}
			}
		}
		.frame(maxHeight: .infinity)
	}
}

private struct RoundControl: View {
	let systemImage: String
	let label: String
	let tint: Color
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			VStack(spacing: 6) {
				Image(systemName: systemImage)
					.font(.system(size: 24, weight: .semibold))
					.frame(width: 68, height: 68)
					.background(tint, in: Circle())
				Text(label)
					.font(.rounded(.footnote, weight: .medium))
			}
			.foregroundStyle(Theme.paper)
		}
		.buttonStyle(.plain)
		.accessibilityLabel(label)
	}
}
