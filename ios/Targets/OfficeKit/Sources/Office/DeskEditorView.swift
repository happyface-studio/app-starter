import SharedKit
import SupabaseKit
import SwiftUI

struct DeskEditorView: View {
	@EnvironmentObject private var office: OfficeStore
	@Environment(\.dismiss) private var dismiss

	@State private var draft: Desk
	@State private var isSaving = false
	@State private var confirmLetGo = false
	let onRemoved: () -> Void

	init(desk: Desk, onRemoved: @escaping () -> Void) {
		_draft = State(initialValue: desk)
		self.onRemoved = onRemoved
	}

	var body: some View {
		Form {
			Section {
				LookEditor(look: $draft.look)
			}

			Section("Who they are") {
				TextField("Name", text: $draft.name)
					.font(.rounded(.body, weight: .semibold))
				TextField("Role, like Receptionist", text: $draft.role)
			}

			Section {
				TextField("Hi, this is Paula. How can I help?", text: $draft.greeting, axis: .vertical)
					.lineLimit(2...4)
			} header: {
				Text("First thing they say")
			} footer: {
				Text("Leave it empty and they'll greet callers in their own words.")
			}

			Section {
				TextEditor(text: $draft.instructions)
					.frame(minHeight: 160)
					.overlay(alignment: .topLeading) {
						if draft.instructions.isEmpty {
							Text(Self.jobExample)
								.foregroundStyle(.tertiary)
								.padding(.top, 8)
								.padding(.leading, 5)
								.allowsHitTesting(false)
						}
					}
			} header: {
				Text("Their job")
			} footer: {
				Text("Write it like you'd brief a new colleague: who you are, what callers usually want, and what they should never promise.")
			}

			Section("Voice") {
				Picker("Speaks", selection: $draft.language) {
					ForEach(DeskLanguage.allCases) { language in
						Text(language.label).tag(language)
					}
				}
				ForEach(VoicePreset.allCases) { preset in
					Button {
						draft.voice = preset.model
					} label: {
						HStack {
							VStack(alignment: .leading, spacing: 2) {
								Text(preset.name).foregroundStyle(.primary)
								Text(preset.detail).font(.footnote).foregroundStyle(.secondary)
							}
							Spacer()
							if draft.voice == preset.model {
								Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
							}
						}
					}
				}
				if VoicePreset.matching(draft.voice) == nil {
					LabeledContent("Custom voice", value: draft.voice)
						.font(.footnote)
				}
			}

			Section {
				Button("Let \(draft.name) go", role: .destructive) { confirmLetGo = true }
			} footer: {
				Text("Their phone number stays yours and can go on another desk.")
			}
		}
		.navigationTitle("Edit \(draft.name)")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .confirmationAction) {
				Button("Save") { Task { await save() } }
					.disabled(isSaving || draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
			}
		}
		.confirmationDialog("Let \(draft.name) go?", isPresented: $confirmLetGo, titleVisibility: .visible) {
			Button("Let \(draft.name) go", role: .destructive) { Task { await remove() } }
		} message: {
			Text("Their desk will be empty. Past calls stay in your call log.")
		}
	}

	private static let jobExample = """
		You answer the phone for Kiez Bikes, a repair shop in Frankfurt. We're open Tuesday to Saturday, 10 to 7. Most repairs take two days. Take a message for anything about an order. Never quote prices.
		"""

	private func save() async {
		isSaving = true
		defer { isSaving = false }
		var desk = draft
		desk.name = desk.name.trimmingCharacters(in: .whitespacesAndNewlines)
		do {
			try await office.save(desk)
			Haptics.notification(type: .success)
			dismiss()
		} catch {
			showInAppNotification(
				.error, content: .init(title: "Couldn't save", message: LocalizedStringKey(error.localizedDescription)))
		}
	}

	private func remove() async {
		do {
			try await office.remove(draft)
			onRemoved()
		} catch {
			showInAppNotification(
				.error, content: .init(title: "Couldn't remove", message: LocalizedStringKey(error.localizedDescription)))
		}
	}
}

/// Look editor: live portrait plus a row per character layer.
struct LookEditor: View {
	@Binding var look: Look

	var body: some View {
		VStack(spacing: 16) {
			ZStack(alignment: .topTrailing) {
				PortraitView(look: look, activity: .speaking)
					.frame(width: 140, height: 140)
					.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
					.frame(maxWidth: .infinity)
				Button {
					Haptics.impact(style: .light)
					look = .random()
				} label: {
					Image(systemName: "shuffle")
						.font(.rounded(.body, weight: .semibold))
				}
				.buttonStyle(.bordered)
				.accessibilityLabel("Shuffle look")
			}

			if let art = OfficeArt.shared {
				SpriteLookRows(art: art, look: $look)
			} else {
				SwatchRow(title: "Skin", colors: PixelArt.skins.map(\.0), selection: $look.skin)
				ChipRow(title: "Hair", names: PixelArt.hairStyleNames, selection: $look.hair)
				SwatchRow(title: "Hair color", colors: PixelArt.hairColors.map(\.0), selection: $look.hairColor)
				SwatchRow(title: "Top", colors: PixelArt.shirts.map(\.0), selection: $look.shirt)
				ChipRow(title: "Extras", names: PixelArt.accessoryNames, selection: $look.accessory)
			}
		}
		.padding(.vertical, 8)
	}
}

private struct SwatchRow: View {
	let title: String
	let colors: [UInt32]
	@Binding var selection: Int

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title).font(.rounded(.footnote, weight: .medium)).foregroundStyle(.secondary)
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 10) {
					ForEach(colors.indices, id: \.self) { index in
						Button {
							selection = index
						} label: {
							RoundedRectangle(cornerRadius: 6, style: .continuous)
								.fill(Color(hex: Int(colors[index])))
								.frame(width: 30, height: 30)
								.overlay {
									RoundedRectangle(cornerRadius: 6, style: .continuous)
										.strokeBorder(Color.primary, lineWidth: selection % colors.count == index ? 2.5 : 0)
										.padding(-4)
								}
						}
						.buttonStyle(.plain)
						.accessibilityLabel("\(title) \(index + 1)")
						.accessibilityAddTraits(selection % colors.count == index ? .isSelected : [])
					}
				}
				.padding(4)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

private struct ChipRow: View {
	let title: String
	let names: [String]
	@Binding var selection: Int

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title).font(.rounded(.footnote, weight: .medium)).foregroundStyle(.secondary)
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 8) {
					ForEach(names.indices, id: \.self) { index in
						Button(names[index]) { selection = index }
							.font(.rounded(.subheadline, weight: .medium))
							.buttonStyle(.bordered)
							.tint(selection % names.count == index ? Color.accentColor : .secondary)
							.accessibilityAddTraits(selection % names.count == index ? .isSelected : [])
					}
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}
