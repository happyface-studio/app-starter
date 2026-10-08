import SharedKit
import SupabaseKit
import SwiftUI

/// Find a number for a desk: plug in one you already have, claim a studio number, or rent a US number.
struct PhonePickerSheet: View {
	@EnvironmentObject private var office: OfficeStore
	@Environment(\.dismiss) private var dismiss

	let desk: Desk

	@State private var pool: [AvailableNumber] = []
	@State private var poolLoaded = false
	@State private var areaCode = ""
	@State private var results: [AvailableNumber] = []
	@State private var isSearching = false
	@State private var busyNumber: String?
	@State private var pendingRent: AvailableNumber?

	var body: some View {
		NavigationStack {
			List {
				let spare = office.unpluggedLines
				if !spare.isEmpty {
					Section("Your numbers") {
						ForEach(spare) { line in
							NumberRow(
								number: PhoneFormat.pretty(line.e164), detail: line.capabilityLabel,
								action: "Plug in", isBusy: busyNumber == line.e164
							) {
								Task { await perform(line.e164) { try await office.plug(line, into: desk) } }
							}
						}
					}
				}

				Section {
					if !poolLoaded {
						ProgressView()
					} else if pool.isEmpty {
						Text("No studio numbers free right now.")
							.foregroundStyle(.secondary)
					}
					ForEach(pool) { number in
						NumberRow(
							number: PhoneFormat.pretty(number.e164),
							detail: number.canOutbound ? "Calls in and out" : "Takes calls only",
							action: "Claim", isBusy: busyNumber == number.e164
						) {
							Task { await perform(number.e164) { try await office.take(number, for: desk) } }
						}
					}
				} header: {
					Text("Studio numbers")
				} footer: {
					Text("Numbers on the studio's own phone line. These can also make calls.")
				}

				Section {
					HStack {
						TextField("Area code, like 415", text: $areaCode)
							.keyboardType(.numberPad)
							.onSubmit { Task { await search() } }
						Button("Search") { Task { await search() } }
							.disabled(isSearching)
					}
					if isSearching {
						ProgressView()
					}
					ForEach(results) { number in
						NumberRow(
							number: PhoneFormat.pretty(number.e164), detail: number.place ?? "United States",
							action: "Rent", isBusy: busyNumber == number.e164
						) {
							pendingRent = number
						}
					}
				} header: {
					Text("New US number")
				} footer: {
					Text("Rented through LiveKit. US numbers take incoming calls only for now.")
				}
			}
			.navigationTitle("Phone for \(desk.name)")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Close") { dismiss() }
				}
			}
			.task { await loadPool() }
			.confirmationDialog(
				"Rent \(pendingRent.map { PhoneFormat.pretty($0.e164) } ?? "")?",
				isPresented: Binding(get: { pendingRent != nil }, set: { if !$0 { pendingRent = nil } }),
				titleVisibility: .visible
			) {
				Button("Rent for \(desk.name)") {
					if let number = pendingRent {
						Task { await perform(number.e164) { try await office.take(number, for: desk) } }
					}
				}
			} message: {
				Text("It's billed monthly to the studio's LiveKit project, even if you give it back early.")
			}
		}
	}

	private func loadPool() async {
		pool = (try? await office.poolNumbers()) ?? []
		poolLoaded = true
	}

	private func search() async {
		isSearching = true
		defer { isSearching = false }
		do {
			results = try await office.searchNumbers(areaCode: areaCode)
			if results.isEmpty {
				showInAppNotification(
					.info, content: .init(title: "No numbers there", message: "Try a different area code."), size: .compact)
			}
		} catch {
			showError(error)
		}
	}

	private func perform(_ number: String, _ work: () async throws -> Void) async {
		busyNumber = number
		defer { busyNumber = nil }
		do {
			try await work()
			Haptics.notification(type: .success)
			dismiss()
		} catch {
			showError(error)
		}
	}

	private func showError(_ error: Error) {
		showInAppNotification(
			.error, content: .init(title: "That didn't work", message: LocalizedStringKey(error.localizedDescription)))
	}
}

private struct NumberRow: View {
	let number: String
	let detail: String
	let action: String
	let isBusy: Bool
	let onTap: () -> Void

	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 2) {
				Text(number).font(.rounded(.body, weight: .semibold)).monospacedDigit()
				Text(detail).font(.footnote).foregroundStyle(.secondary)
			}
			Spacer()
			if isBusy {
				ProgressView()
			} else {
				Button(action, action: onTap)
					.buttonStyle(.bordered)
					.font(.rounded(.subheadline, weight: .semibold))
			}
		}
	}
}

/// Every number you have, and which desk it rings.
struct LinesSheet: View {
	@EnvironmentObject private var office: OfficeStore
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			List {
				if office.lines.isEmpty {
					ContentUnavailableView(
						"No numbers yet",
						systemImage: "phone.badge.plus",
						description: Text("Open a desk and give its deskmate a phone number.")
					)
					.listRowBackground(Color.clear)
				}
				ForEach(office.lines) { line in
					VStack(alignment: .leading, spacing: 4) {
						Text(PhoneFormat.pretty(line.e164))
							.font(.rounded(.title3, weight: .semibold))
							.monospacedDigit()
							.textSelection(.enabled)
						Text(ringsText(for: line))
							.font(.rounded(.subheadline))
							.foregroundStyle(.secondary)
						Text(line.capabilityLabel)
							.font(.footnote)
							.foregroundStyle(.tertiary)
					}
					.padding(.vertical, 2)
				}
			}
			.navigationTitle("Phone lines")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
		}
	}

	private func ringsText(for line: PhoneLine) -> String {
		guard let desk = office.desk(id: line.deskID) else { return "Not on a desk. Calls get a short message." }
		return "Rings \(desk.name)'s desk"
	}
}

/// Send a deskmate to call someone with a short brief.
struct DialSheet: View {
	@EnvironmentObject private var office: OfficeStore
	@Environment(\.dismiss) private var dismiss

	let desk: Desk

	@State private var number = "+"
	@State private var brief = ""
	@State private var isCalling = false
	@FocusState private var numberFocused: Bool

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField("+49 151 23456789", text: $number)
						.keyboardType(.phonePad)
						.textContentType(.telephoneNumber)
						.font(.rounded(.title2, weight: .semibold))
						.monospacedDigit()
						.focused($numberFocused)
				} header: {
					Text("Number to call")
				} footer: {
					Text("Include the country code.")
				}
				Section {
					TextField(
						"Book a table for four this Friday at 8pm. Name is Weber. Ask if the terrace is open.",
						text: $brief, axis: .vertical
					)
					.lineLimit(3...8)
				} header: {
					Text("What should \(desk.name) say?")
				}
			}
			.navigationTitle("\(desk.name) calls")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Call") { Task { await call() } }
						.disabled(isCalling || cleanNumber.count < 8)
				}
			}
			.onAppear { numberFocused = true }
		}
		.presentationDetents([.medium, .large])
	}

	private var cleanNumber: String {
		number.filter { $0.isNumber || $0 == "+" }
	}

	private func call() async {
		isCalling = true
		defer { isCalling = false }
		do {
			try await office.placeCall(from: desk, to: cleanNumber, brief: brief)
			Haptics.notification(type: .success)
			showInAppNotification(
				.success,
				content: .init(title: "\(desk.name) is dialing", message: LocalizedStringKey(PhoneFormat.pretty(cleanNumber))),
				size: .compact)
			dismiss()
		} catch {
			showInAppNotification(
				.error, content: .init(title: "Call didn't start", message: LocalizedStringKey(error.localizedDescription)))
		}
	}
}
