import AnalyticsKit
import SupabaseKit
import SwiftUI

/// Every call the office handled, newest first, with messages taken along the way.
public struct CallsView: View {
	@EnvironmentObject private var db: DB
	@EnvironmentObject private var office: OfficeStore

	public init() {}

	public var body: some View {
		NavigationStack {
			List {
				let messages = office.calls.filter { $0.message != nil }.prefix(5)
				if !messages.isEmpty {
					Section("Messages") {
						ForEach(Array(messages)) { call in
							NavigationLink {
								CallDetailView(callID: call.id)
							} label: {
								MessageRow(call: call)
							}
						}
					}
				}
				Section("All calls") {
					if office.calls.isEmpty {
						Text("Calls your deskmates take or make show up here, with a transcript.")
							.foregroundStyle(.secondary)
					}
					ForEach(office.calls) { call in
						NavigationLink {
							CallDetailView(callID: call.id)
						} label: {
							CallRow(call: call)
						}
						.swipeActions {
							if !call.isLive {
								Button("Delete", role: .destructive) {
									Task { try? await office.delete(call) }
								}
							}
						}
					}
				}
			}
			.navigationTitle("Calls")
			.refreshable { await office.load() }
		}
		.requireLogin(db: db, navTitle: "Sign in to see your calls", onCancel: {})
		.captureViewActivity(as: "CallsView")
	}
}

struct CallRow: View {
	@EnvironmentObject private var office: OfficeStore
	let call: Call

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: icon)
				.font(.rounded(.body, weight: .semibold))
				.foregroundStyle(tint)
				.frame(width: 28)
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.rounded(.body, weight: .medium))
				Text(subtitle)
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
			Spacer()
			Text(call.startedAt, format: .relative(presentation: .named))
				.font(.footnote)
				.foregroundStyle(.secondary)
		}
		.accessibilityElement(children: .combine)
	}

	private var deskName: String { office.desk(id: call.deskID)?.name ?? "Unassigned" }

	private var title: String {
		switch call.direction {
			case .web: "You and \(deskName)"
			case .inbound: PhoneFormat.pretty(call.remoteNumber)
			case .outbound: PhoneFormat.pretty(call.remoteNumber)
		}
	}

	private var subtitle: String {
		let who =
			switch call.direction {
				case .web: "In the app"
				case .inbound: "Called \(deskName)"
				case .outbound: "\(deskName) called"
			}
		return "\(who), \(CallCopy.summary(for: call).lowercased())"
	}

	private var icon: String {
		if call.isLive { return "waveform" }
		switch (call.direction, call.status) {
			case (_, .missed): return "phone.down"
			case (_, .failed): return "exclamationmark.triangle"
			case (.inbound, _): return "phone.arrow.down.left"
			case (.outbound, _): return "phone.arrow.up.right"
			case (.web, _): return "iphone"
		}
	}

	private var tint: Color {
		if call.isLive { return Theme.mint }
		switch call.status {
			case .missed, .failed: return .red
			default: return .secondary
		}
	}
}

private struct MessageRow: View {
	@EnvironmentObject private var office: OfficeStore
	let call: Call

	var body: some View {
		if let message = call.message {
			VStack(alignment: .leading, spacing: 4) {
				HStack {
					Text(message.callerName).font(.rounded(.body, weight: .semibold))
					Spacer()
					Text(call.startedAt, format: .relative(presentation: .named))
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
				Text(message.text)
					.font(.callout)
					.lineLimit(2)
				if let name = office.desk(id: call.deskID)?.name {
					Text("Taken by \(name)")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
		}
	}
}

struct CallDetailView: View {
	@EnvironmentObject private var office: OfficeStore
	let callID: UUID

	var body: some View {
		if let call = office.calls.first(where: { $0.id == callID }) {
			List {
				if let message = call.message {
					Section("Message") {
						VStack(alignment: .leading, spacing: 6) {
							Text(message.callerName).font(.rounded(.headline))
							Text(message.text)
							if let number = message.callbackNumber, !number.isEmpty {
								Link(
									"Call back \(PhoneFormat.pretty(number))",
									destination: URL(string: "tel:\(number.filter { $0.isNumber || $0 == "+" })")!)
							}
						}
						.padding(.vertical, 4)
					}
				}
				Section {
					LabeledContent("Status", value: CallCopy.summary(for: call))
					LabeledContent("Started", value: call.startedAt.formatted(date: .abbreviated, time: .shortened))
					if call.direction != .web {
						LabeledContent("Other side", value: PhoneFormat.pretty(call.remoteNumber))
					}
				}
				Section("Transcript") {
					if call.transcript.isEmpty {
						Text("Nothing was said.").foregroundStyle(.secondary)
					}
					ForEach(Array(call.transcript.enumerated()), id: \.offset) { _, line in
						TranscriptBubble(line: line, compact: false)
							.listRowSeparator(.hidden)
					}
				}
			}
			.navigationTitle(office.desk(id: call.deskID)?.name ?? "Call")
			.navigationBarTitleDisplayMode(.inline)
		} else {
			ContentUnavailableView("Call deleted", systemImage: "phone.down")
		}
	}
}

struct TranscriptBubble: View {
	let text: String
	let isAgent: Bool
	var compact: Bool

	init(text: String, isAgent: Bool, compact: Bool = false) {
		self.text = text
		self.isAgent = isAgent
		self.compact = compact
	}

	init(line: TranscriptLine, compact: Bool) {
		self.init(text: line.text, isAgent: line.isAgent, compact: compact)
	}

	var body: some View {
		HStack {
			if !isAgent { Spacer(minLength: 40) }
			Text(text)
				.font(compact ? .footnote : .callout)
				.lineLimit(compact ? 2 : nil)
				.padding(.horizontal, 12)
				.padding(.vertical, 8)
				.background(
					isAgent ? Theme.brass.opacity(0.35) : Color.secondary.opacity(0.15),
					in: RoundedRectangle(cornerRadius: 14, style: .continuous))
			if isAgent { Spacer(minLength: 40) }
		}
	}
}
