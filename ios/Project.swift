import ProjectDescription

// MARK: - Project

let project = tuistProject()

func tuistProject() -> Project {

	// Dont use spaces here
	let appName = "Deskmates"

	// You can use spaces here
	let appDisplayName = "Deskmates"

	// Your app's bundle id. Bundle ID of all other modules will use this as a prefix
	let bundleID = "studio.happyface.deskmates"

	// Minimum deployment version
	let osVersion = "18.0"

	// Your app's public version
	let appVersion = "1.0.0"

	// Your app's "internal" version = build number
	let appBuildNumber = "1"

	let destinations: ProjectDescription.Destinations = [
		.iPhone,
		.iPad,
		.macWithiPadDesign,
		.appleVisionWithiPadDesign,
	]

	var projectTargets: [Target] = []
	var projectPackages: [Package] = []
	var appDependencies: [TargetDependency] = []
	let baseAppResources = ResourceFileElement.glob(pattern: "Targets/App/Resources/**")  // will be also included inside each module. This will allow us to tap into the Resources of App/ from any module
	var appResources: [ResourceFileElement] = [baseAppResources]
	var appEntitlements: [String: Plist.Value] = [:]
	var appInfoPlist: [String: Plist.Value] = [
		"CFBundleShortVersionString": "$(MARKETING_VERSION)",
		"CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
		"CFBundleDisplayName": .string(appDisplayName),
		"NSFaceIDUsageDescription": "We will use FaceID to authenticate you",
		"NSCameraUsageDescription": "We need Camera Access for the App to work.",
		"NSLocationAlwaysAndWhenInUseUsageDescription": "We need Location Access for the App to work.",
		"NSLocationWhenInUseUsageDescription": "We need Location Access for the App to work.",
		"NSContactsUsageDescription": "We need Contacts Access for the App to work.",
		"NSMicrophoneUsageDescription": "We need Microhone Access for the App to work.",
		"NSCalendarsFullAccessUsageDescription": "We need Calendar Access for the App to work.",
		"NSRemindersFullAccessUsageDescription": "We need Reminders Access for the App to work.",
		"NSPhotoLibraryUsageDescription": "We need Photo Library Access for the App to work.",
		"UILaunchStoryboardName": "LaunchScreen",
		"UISupportedInterfaceOrientations": .array(["UIInterfaceOrientationPortrait"]),  //Only Support Portrait on iphone
	]

	// Info Property List values that are included with each module (usable by extending the default info plist
	let defaultModuleInfoPlist: [String: Plist.Value] = [
		"CFBundleShortVersionString": "$(MARKETING_VERSION)",
		"CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
	]

	let sharedKit = TargetDependency.target(name: "SharedKit")
	let analyticsKit = TargetDependency.target(name: "AnalyticsKit")

	addSharedKit()
	addAnalyticsKit()
	addNotifKit()
	let iapKit = addInAppPurchaseKit()
	addSupabaseKit()

	addApp()

	return Project(
		name: appName,
		options: .options(
			disableSynthesizedResourceAccessors: true,
			textSettings: .textSettings(
				usesTabs: false,
				indentWidth: 4,
				tabWidth: 4,
				wrapsLines: true
			)
		),
		packages: projectPackages,
		settings: .settings(base: [
			"ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES": "AppIcon-Alt-1 AppIcon-Alt-2",
			"ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS": "YES",
			"MARKETING_VERSION": .string(appVersion),
			"CURRENT_PROJECT_VERSION": .string(appBuildNumber),
		]),
		targets: projectTargets
	)

	func addApp() {
		let mainTarget: Target = .target(
			name: appName,
			destinations: destinations,
			product: .app,
			bundleId: bundleID,
			deploymentTargets: .iOS(osVersion),
			infoPlist: .extendingDefault(with: appInfoPlist),
			sources: ["Targets/App/Sources/**"],
			resources: .resources(appResources),
			entitlements: .dictionary(appEntitlements),
			scripts: [],
			dependencies: appDependencies,
			settings: .settings(base: [
				"OTHER_LDFLAGS": "-ObjC",
				"ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor"

					,
				"ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",

			])
		)

		projectTargets.append(mainTarget)
	}

	// Code Shared Across all targets
	func addSharedKit() {
		let targetName = "SharedKit"
		let sharedTarget: Target = .target(
			name: targetName,
			destinations: destinations,
			product: .framework,
			bundleId: "\(bundleID).\(targetName)",
			deploymentTargets: .iOS(osVersion),
			infoPlist: .extendingDefault(with: defaultModuleInfoPlist),
			sources: ["Targets/\(targetName)/Sources/**"],
			resources: [
				"Targets/\(targetName)/Resources/**",
				baseAppResources,
			],
			dependencies: [],
			settings: .settings(base: [
				"ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES"
			])
		)

		appDependencies.append(sharedKit)
		projectTargets.append(sharedTarget)
	}

	func addInAppPurchaseKit() -> TargetDependency {
		let targetName = "InAppPurchaseKit"
		let iapTarget: Target = .target(
			name: targetName,
			destinations: destinations,
			product: .framework,
			bundleId: "\(bundleID).\(targetName)",
			deploymentTargets: .iOS(osVersion),
			infoPlist: .extendingDefault(with: defaultModuleInfoPlist),
			sources: ["Targets/\(targetName)/Sources/**"],
			resources: [
				"Targets/\(targetName)/Resources/**",
				baseAppResources,
			],
			dependencies: [
				sharedKit,
				analyticsKit,
				TargetDependency.package(product: "RevenueCat", type: .runtime),
				TargetDependency.package(product: "RevenueCatUI", type: .runtime),
			],
			settings: .settings(base: [
				"ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES"
			])
		)
		let targetDependency = TargetDependency.target(name: targetName)
		appDependencies.append(targetDependency)
		appDependencies.append(TargetDependency.sdk(name: "StoreKit", type: .framework, status: .required))  //In-App Purchase Capability
		projectPackages
			.append(
				.remote(
					url: "https://github.com/RevenueCat/purchases-ios.git",
					requirement: .exact("5.8.0")
				)
			)
		projectTargets.append(iapTarget)
		appResources.append("Targets/\(targetName)/Config/RevenueCat-Info.plist")
		return targetDependency
	}

	func addAnalyticsKit() {
		let targetName = "AnalyticsKit"
		let analyticsTarget: Target = .target(
			name: targetName,
			destinations: destinations,
			product: .framework,
			bundleId: "\(bundleID).\(targetName)",
			deploymentTargets: .iOS(osVersion),
			infoPlist: .extendingDefault(with: defaultModuleInfoPlist),
			sources: ["Targets/\(targetName)/Sources/**"],
			resources: [baseAppResources],
			dependencies: [
				sharedKit,
				TargetDependency.package(product: "PostHog", type: .runtime),
			],
			settings: .settings(base: [
				"ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES"
			])
		)
		appDependencies.append(TargetDependency.target(name: targetName))
		projectPackages
			.append(
				.remote(
					url: "https://github.com/PostHog/posthog-ios.git",
					requirement: .exact("3.21.0")
				)
			)
		projectTargets.append(analyticsTarget)
		appResources.append("Targets/\(targetName)/Config/PostHog-Info.plist")
	}

	func addNotifKit() {
		let notifTargetName = "NotifKit"
		let notifTarget: Target = .target(
			name: notifTargetName,
			destinations: destinations,
			product: .framework,
			bundleId: "\(bundleID).\(notifTargetName)",
			deploymentTargets: .iOS(osVersion),
			infoPlist: .extendingDefault(with: defaultModuleInfoPlist),
			sources: ["Targets/\(notifTargetName)/Sources/**"],
			resources: [baseAppResources],
			dependencies: [
				sharedKit,
				TargetDependency.package(product: "OneSignalFramework", type: .runtime),
				analyticsKit,
			],
			settings: .settings(base: [
				"ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES"
			])
		)

		appDependencies.append(TargetDependency.target(name: notifTargetName))

		// Also have to include that, otherwise the app crashes
		appDependencies.append(TargetDependency.package(product: "OneSignalFramework", type: .runtime))
		appResources.append("Targets/\(notifTargetName)/Config/OneSignal-Info.plist")

		appInfoPlist["UIBackgroundModes"] = .array(["remote-notification"])

		projectPackages.append(
			.remote(
				url: "https://github.com/OneSignal/OneSignal-iOS-SDK.git",
				requirement: .exact("5.2.10")
			)
		)
		projectTargets.append(notifTarget)
		let notifExtensionTargetName = "OneSignalNotificationServiceExtension"
		let notifExtensionTarget: Target = .target(
			name: notifExtensionTargetName,
			destinations: .iOS,
			product: .appExtension,
			bundleId: "\(bundleID).\(notifExtensionTargetName)",
			deploymentTargets: .iOS(osVersion),
			infoPlist: .dictionary(
				[
					"NSExtension": [
						"NSExtensionPointIdentifier": "com.apple.usernotifications.service",
						"NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).NotificationService",
					]
				].merging(defaultModuleInfoPlist) { (current, _) in current }),  // merge two dictionaries
			sources: ["Targets/\(notifTargetName)/\(notifExtensionTargetName)/**"],
			entitlements:
				Entitlements
				.dictionary(
					[
						"com.apple.security.application-groups": .array(["group.\(bundleID).onesignal"])
					]
				),
			dependencies: [TargetDependency.package(product: "OneSignalExtension", type: .runtime)],
			settings: .settings(base: [
				"ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES"
			])
		)
		appEntitlements["aps-environment"] = .string("development")
		appEntitlements["com.apple.security.application-groups"] = .array(["group.\(bundleID).onesignal"])
		projectTargets.append(notifExtensionTarget)
	}

	// Supabase Auth + DB
	@discardableResult
	func addSupabaseKit() -> TargetDependency {
		let targetName = "SupabaseKit"
		let supabaseTarget: Target = .target(
			name: targetName,
			destinations: destinations,
			product: .framework,
			bundleId: "\(bundleID).\(targetName)",
			deploymentTargets: .iOS(osVersion),
			infoPlist: .extendingDefault(with: defaultModuleInfoPlist),
			sources: ["Targets/\(targetName)/Sources/**"],
			resources: [baseAppResources],
			dependencies: [
				TargetDependency.package(product: "Supabase", type: .runtime),
				analyticsKit,
				sharedKit,
			],
			settings: .settings(base: [
				"ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES"
			])
		)
		let targetDependency = TargetDependency.target(name: targetName)
		appDependencies.append(targetDependency)
		projectPackages
			.append(
				.remote(
					url: "https://github.com/supabase-community/supabase-swift.git",
					requirement: .exact("2.20.5")
				)
			)
		projectTargets.append(supabaseTarget)
		appEntitlements["com.apple.developer.applesignin"] = .array(["Default"])  // Sign in with Apple Capability
		appResources.append("Targets/\(targetName)/Config/Supabase-Info.plist")
		return targetDependency

	}
}
