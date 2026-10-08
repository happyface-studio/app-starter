import SharedKit
import SupabaseKit
import SwiftUI

struct HireSheet: View {
	@EnvironmentObject private var office: OfficeStore
	@Environment(\.dismiss) private var dismiss

	let seat: Int
	let onHired: (Desk) -> Void

	@State private var isHiring = false
	@State private var look = Look.random()

	var body: some View {
		VStack(spacing: 20) {
			PortraitView(look: look, activity: .idle)
				.frame(width: 120, height: 120)
				.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
				.overlay(alignment: .bottomTrailing) {
					Button {
						Haptics.impact(style: .light)
						look = .random()
					} label: {
						Image(systemName: "shuffle.circle.fill")
							.font(.system(size: 30))
							.symbolRenderingMode(.palette)
							.foregroundStyle(Theme.paper, Theme.coral)
					}
					.accessibilityLabel("Someone else")
					.offset(x: 10, y: 10)
				}
			VStack(spacing: 6) {
				Text("Hire a deskmate")
					.font(.rounded(.title2, weight: .bold))
				Text("They'll answer calls, take messages and ring people for you. You can change their name, voice and job right after.")
					.font(.rounded(.callout))
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			Button {
				Task { await hire() }
			} label: {
				if isHiring { ProgressView().tint(.white) } else { Text("Hire") }
			}
			.buttonStyle(.cta())
			.disabled(isHiring)
		}
		.padding(24)
		.presentationDetents([.height(400)])
		.presentationCornerRadius(32)
	}

	private func hire() async {
		isHiring = true
		defer { isHiring = false }
		do {
			let desk = try await office.hire(seat: seat, look: look)
			Haptics.notification(type: .success)
			onHired(desk)
		} catch {
			showInAppNotification(
				.error, content: .init(title: "Couldn't hire", message: LocalizedStringKey(error.localizedDescription)))
		}
	}
}

struct DeskSheet: View {
	@EnvironmentObject private var office: OfficeStore
	@Environment(\.dismiss) private var dismiss

	let deskID: UUID
	@Binding var callRoute: CallRoute?

	@State private var showPhonePicker = false
	@State private var showDialer = false
	@State private var confirmRelease = false

	var body: some View {
		NavigationStack {
			if let desk = office.desk(id: deskID) {
				content(desk)
			} else {
				ContentUnavailableView("This desk is empty now", systemImage: "chair")
			}
		}
		.presentationDetents([.large])
		.presentationCornerRadius(32)
	}

	@ViewBuilder
	private func content(_ desk: Desk) -> some View {
		let line = office.line(for: desk)
		let live = office.liveCall(for: desk)
		List {
			Section {
				header(desk, live: live)
			}
			.listRowBackground(Color.clear)
			.listRowInsets(EdgeInsets())

			if let live {
				Section("On the phone") {
					LiveCallDetail(call: live) {
						if live.direction != .web {
							dismiss()
							callRoute = .listen(callID: live.id)
						}
					}
				}
			}

			Section {
				Button {
					dismiss()
					callRoute = .talk(deskID: desk.id)
				} label: {
					Label("Talk to \(desk.name)", systemImage: "waveform")
						.font(.rounded(.body, weight: .semibold))
				}
				.disabled(live != nil)

				Button {
					showDialer = true
				} label: {
					Label("Have \(desk.name) call someone", systemImage: "phone.arrow.up.right")
				}
				.disabled(line?.canOutbound != true || live != nil)
			} footer: {
				if live != nil {
					Text("\(desk.name) is busy on another call.")
				} else if line == nil {
					Text("Talking in the app works without a phone number.")
				} else if line?.canOutbound == false {
					Text("This number takes calls only. Outbound calls need a studio number.")
				}
			}

			Section("Phone") {
				if let line {
					VStack(alignment: .leading, spacing: 2) {
						Text(PhoneFormat.pretty(line.e164))
							.font(.rounded(.title3, weight: .semibold))
							.monospacedDigit()
							.textSelection(.enabled)
						Text(line.capabilityLabel + (line.locality.map { ", \($0)" } ?? ""))
							.font(.rounded(.footnote))
							.foregroundStyle(.secondary)
					}
					Button("Swap number") { showPhonePicker = true }
					Button("Unplug from this desk") {
						Task { await run { try await office.plug(line, into: nil) } }
					}
					Button("Give number back", role: .destructive) { confirmRelease = true }
				} else {
					Button {
						showPhonePicker = true
					} label: {
						Label("Give \(desk.name) a phone number", systemImage: "phone.badge.plus")
					}
				}
			}

			let history = office.calls.filter { $0.deskID == desk.id && !$0.isLive }.prefix(5)
			if !history.isEmpty {
				Section("Recent calls") {
					ForEach(Array(history)) { call in
						NavigationLink {
							CallDetailView(callID: call.id)
						} label: {
							CallRow(call: call)
						}
					}
				}
			}
		}
		.navigationTitle(desk.name)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .topBarLeading) {
				Button("Done") { dismiss() }
			}
			ToolbarItem(placement: .topBarTrailing) {
				NavigationLink("Edit") {
					DeskEditorView(desk: desk) { dismiss() }
				}
			}
		}
		.sheet(isPresented: $showPhonePicker) {
			PhonePickerSheet(desk: desk)
		}
		.sheet(isPresented: $showDialer) {
			DialSheet(desk: desk)
		}
		.confirmationDialog(
			"Give \(line.map { PhoneFormat.pretty($0.e164) } ?? "this number") back?",
			isPresented: $confirmRelease, titleVisibility: .visible
		) {
			Button("Give number back", role: .destructive) {
				if let line { Task { await run { try await office.release(line) } } }
			}
		} message: {
			Text("People calling it won't reach \(desk.name) anymore, and you may not get the same number again.")
		}
	}

	private func header(_ desk: Desk, live: Call?) -> some View {
		VStack(spacing: 12) {
			PortraitView(look: desk.look, activity: DeskActivity(call: live))
				.frame(width: 132, height: 132)
				.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
			VStack(spacing: 2) {
				Text(desk.name)
					.font(.rounded(.title, weight: .bold))
				Text(desk.role)
					.font(.rounded(.callout))
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 8)
	}

	private func run(_ work: () async throws -> Void) async {
		do {
			try await work()
		} catch {
			showInAppNotification(
				.error, content: .init(title: "That didn't work", message: LocalizedStringKey(error.localizedDescription)))
		}
	}
}

struct LiveCallDetail: View {
	@EnvironmentObject private var office: OfficeStore
	let call: Call
	let onListen: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(CallCopy.headline(for: call, deskName: office.desk(id: call.deskID)?.name))
				.font(.rounded(.headline))
			ForEach(Array(call.transcript.suffix(3).enumerated()), id: \.offset) { _, line in
				TranscriptBubble(line: line, compact: true)
			}
			HStack {
				if call.direction != .web {
					Button("Listen in", action: onListen)
						.buttonStyle(.borderedProminent)
				}
				Button("Hang up", role: .destructive) {
					Task { try? await office.hangUp(call) }
				}
				.buttonStyle(.bordered)
			}
			.font(.rounded(.subheadline, weight: .semibold))
		}
		.padding(.vertical, 4)
	}
}
