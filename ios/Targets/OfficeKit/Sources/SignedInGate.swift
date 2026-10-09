import SharedKit
import SupabaseKit
import SwiftUI

/// Shows the content only when signed in. Waits for Supabase to restore the session at launch
/// so returning users don't see a sign-in prompt flash by.
struct SignedInGate<Content: View>: View {
	@EnvironmentObject private var db: DB
	let prompt: String
	@ViewBuilder var content: () -> Content

	var body: some View {
		if !db.hasResolvedAuth {
			ProgressView()
				.tint(Theme.paper)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(Theme.carpet.ignoresSafeArea())
		} else if db.authState == .signedIn {
			content()
		} else {
			VStack(spacing: 20) {
				PortraitView(look: Look(skin: 1, hair: 1, hairColor: 2, shirt: 0, accessory: 0), activity: .idle, hasLine: false)
					.frame(width: 140, height: 140)
					.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
				Text(prompt)
					.font(.rounded(.title3, weight: .semibold))
					.foregroundStyle(Theme.paper)
					.multilineTextAlignment(.center)
				Button("Sign in") { db.showSignInSheet() }
					.buttonStyle(.cta())
					.frame(maxWidth: 240)
			}
			.padding(32)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(Theme.carpet.ignoresSafeArea())
		}
	}
}
