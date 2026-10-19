import MapboxMaps
import SwiftUI

public struct ExploreView: View {
    @State private var store = ExploreStore()
    @State private var viewport = CityMapView.initialViewport
    @State private var detent: PresentationDetent = .half
    @State private var hasToken = MapboxToken.resolve()

    public init() {}

    public var body: some View {
        Group {
            if hasToken {
                CityMapView(store: store, viewport: $viewport, bottomInset: 96)
                    .overlay(alignment: .topTrailing) {
                        MapControls(store: store, viewport: $viewport)
                            .padding(.trailing, 14)
                            .padding(.top, 8)
                    }
                    .sheet(isPresented: .constant(true)) {
                        ExploreSheet(store: store, detent: $detent)
                            .presentationDetents([.peek, .half, .large], selection: $detent)
                            .presentationBackgroundInteraction(.enabled(upThrough: .half))
                            .presentationDragIndicator(.visible)
                            .interactiveDismissDisabled()
                    }
            } else {
                TokenMissingView { hasToken = MapboxToken.resolve() }
            }
        }
        .onAppear(perform: applyLaunchArguments)
    }

    private func applyLaunchArguments() {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: "select") {
            store.selection = store.places.contains { $0.id == id } ? .place(id) : .event(id)
        }
        if let mood = defaults.string(forKey: "mood").flatMap(MapMood.init(rawValue:)) { store.mood = mood }
        if let f = defaults.string(forKey: "filter") {
            store.filter = Filter.all.first { $0.id == f }
        }
        switch defaults.string(forKey: "detent") {
        case "peek": detent = .peek
        case "large": detent = .large
        default: break
        }
        if let q = defaults.string(forKey: "query") { store.query = q }
    }
}

enum MapboxToken {
    static let defaultsKey = "mapboxAccessToken"

    /// Info.plist token (from Secrets.xcconfig) first, then one pasted in-app during development.
    static func resolve() -> Bool {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String) ?? ""
        if plist.hasPrefix("pk.") { return true }
        if let saved = UserDefaults.standard.string(forKey: defaultsKey), saved.hasPrefix("pk.") {
            MapboxOptions.accessToken = saved
            return true
        }
        return false
    }
}

struct TokenMissingView: View {
    var onSave: () -> Void
    @State private var token = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 40))
                .foregroundStyle(Palette.orange)
            Text("Add a Mapbox token")
                .font(.system(.title, design: .rounded, weight: .bold))
            Text("Put `MAPBOX_ACCESS_TOKEN = pk…` in ios/Secrets.xcconfig and rebuild, or paste a public token here for this device.")
                .foregroundStyle(.secondary)
            TextField("pk.eyJ…", text: $token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.06)))
            Button("Use token") {
                UserDefaults.standard.set(token.trimmingCharacters(in: .whitespacesAndNewlines), forKey: MapboxToken.defaultsKey)
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!token.hasPrefix("pk."))
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(red: 0.97, green: 0.94, blue: 0.88))
    }
}

struct MapControls: View {
    @Bindable var store: ExploreStore
    @Binding var viewport: Viewport

    var body: some View {
        VStack(spacing: 0) {
            Menu {
                Picker("Light", selection: $store.mood) {
                    ForEach(MapMood.allCases) { mood in
                        Label(mood.title, systemImage: mood.symbol).tag(mood)
                    }
                }
            } label: {
                controlIcon(store.mood.symbol)
            }
            Divider().frame(width: 28)
            Button {
                store.is3D.toggle()
            } label: {
                Text(store.is3D ? "2D" : "3D")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 46, height: 46)
            }
            Divider().frame(width: 28)
            Button {
                withViewportAnimation(.fly(duration: 1)) {
                    viewport = .followPuck(zoom: 16.5, bearing: .constant(0), pitch: store.is3D ? 60 : 0)
                }
            } label: {
                controlIcon("location.fill")
            }
        }
        .buttonStyle(.plain)
        .glassBackground()
    }

    private func controlIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(width: 46, height: 46)
    }
}

private extension View {
    @ViewBuilder
    func glassBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
    }
}
