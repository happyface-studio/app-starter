import ProjectDescription

let project = tuistProject()

func tuistProject() -> Project {

	// Dont use spaces here
	let appName = "Spots"

	// You can use spaces here
	let appDisplayName = "Spots"

	let bundleID = "studio.happyface.spots"

	let osVersion = "18.0"

	let appVersion = "0.1.0"

	let appBuildNumber = "1"

	let destinations: ProjectDescription.Destinations = [.iPhone]

	var projectTargets: [Target] = []
	var appDependencies: [TargetDependency] = []
	let baseAppResources = ResourceFileElement.glob(pattern: "Targets/App/Resources/**")

	let appInfoPlist: [String: Plist.Value] = [
		"CFBundleShortVersionString": "$(MARKETING_VERSION)",
		"CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
		"CFBundleDisplayName": .string(appDisplayName),
		"MBXAccessToken": "$(MAPBOX_ACCESS_TOKEN)",
		"NSLocationWhenInUseUsageDescription": "Spots shows where you are on the map so you can find places nearby.",
		"UILaunchStoryboardName": "LaunchScreen",
		"UISupportedInterfaceOrientations": .array(["UIInterfaceOrientationPortrait"]),
		"UIUserInterfaceStyle": "Light",
	]

	let defaultModuleInfoPlist: [String: Plist.Value] = [
		"CFBundleShortVersionString": "$(MARKETING_VERSION)",
		"CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
	]

	let sharedKit = TargetDependency.target(name: "SharedKit")

	addSharedKit()
	addExploreKit()
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
		packages: [
			.remote(
				url: "https://github.com/mapbox/mapbox-maps-ios.git",
				requirement: .upToNextMinor(from: "11.26.0")
			)
		],
		settings: .settings(
			base: [
				"MARKETING_VERSION": .string(appVersion),
				"CURRENT_PROJECT_VERSION": .string(appBuildNumber),
			],
			configurations: [
				.debug(name: .debug, xcconfig: "Secrets.xcconfig"),
				.release(name: .release, xcconfig: "Secrets.xcconfig"),
			]
		),
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
			resources: .resources([baseAppResources]),
			dependencies: appDependencies,
			settings: .settings(base: [
				"ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
				"ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
			])
		)
		projectTargets.append(mainTarget)
	}

	func addSharedKit() {
		let targetName = "SharedKit"
		let target: Target = .target(
			name: targetName,
			destinations: destinations,
			product: .framework,
			bundleId: "\(bundleID).\(targetName)",
			deploymentTargets: .iOS(osVersion),
			infoPlist: .extendingDefault(with: defaultModuleInfoPlist),
			sources: ["Targets/\(targetName)/Sources/**"],
			resources: ["Targets/\(targetName)/Resources/**", baseAppResources],
			dependencies: [],
			settings: .settings(base: [
				"ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES"
			])
		)
		appDependencies.append(sharedKit)
		projectTargets.append(target)
	}

	// Map, sheet and place data
	func addExploreKit() {
		let targetName = "ExploreKit"
		let target: Target = .target(
			name: targetName,
			destinations: destinations,
			product: .framework,
			bundleId: "\(bundleID).\(targetName)",
			deploymentTargets: .iOS(osVersion),
			infoPlist: .extendingDefault(with: defaultModuleInfoPlist),
			sources: ["Targets/\(targetName)/Sources/**"],
			resources: ["Targets/\(targetName)/Resources/**"],
			dependencies: [
				sharedKit,
				.package(product: "MapboxMaps", type: .runtime),
			]
		)
		appDependencies.append(.target(name: targetName))
		projectTargets.append(target)
	}
}
