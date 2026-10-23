import MapboxMaps

/// `-probe x,y;x,y` (screen points) prints which layers and features are under those points once
/// the map settles. For look debugging only.
@MainActor
enum DebugProbe {
    private static var done = false

    static func run(_ map: MapboxMap) {
        guard !done, let spec = UserDefaults.standard.string(forKey: "probe") else { return }
        done = true
        for pair in spec.split(separator: ";") {
            let v = pair.split(separator: ",").compactMap { Double($0) }
            guard v.count == 2 else { continue }
            let pt = CGPoint(x: v[0], y: v[1])
            _ = map.queryRenderedFeatures(with: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4),
                                          options: RenderedQueryOptions(layerIds: nil, filter: nil)) { result in
                guard case .success(let hits) = result else { return }
                for h in hits.prefix(6) {
                    print("PROBE", pt, h.queriedFeature.sourceLayer ?? "-", h.layers, String(describing: h.queriedFeature.feature.properties))
                }
            }
        }
    }
}
