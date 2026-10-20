import Foundation
import MapboxMaps
import Observation

/// Mapbox Standard, patched so landmark models and ordinary buildings read as one city:
/// landmark walls/roofs get our cream (Standard hard-codes them white/peach), and
/// ordinary façade windows get the landmarks' blue glass instead of desaturated wall colour.
///
/// Standard's layer paint can't be changed through the import API, so we fetch the style JSON,
/// patch the two layers and re-import it inline under the id `basemap` — config still applies.
@Observable
@MainActor
final class Basemap {
    static let shared = Basemap()

    private(set) var json: String?
    private(set) var isResolved = false

    private let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("standard-patched-v3.json")

    private init() {
        if let cached = try? String(contentsOf: cacheURL, encoding: .utf8) {
            json = cached
            isResolved = true
        }
        Task { await refresh() }
    }

    private func refresh() async {
        defer { isResolved = true }
        let token = MapboxOptions.accessToken
        guard !token.isEmpty,
              let url = URL(string: "https://api.mapbox.com/styles/v1/mapbox/standard?access_token=\(token)"),
              let result = try? await URLSession.shared.data(from: url),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              var style = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any]
        else { return }

        Self.patch(&style)
        let wrapper: [String: Any] = [
            "version": 8,
            "imports": [["id": "basemap", "url": "mapbox://styles/mapbox/standard", "data": style]],
            "sources": [String: Any](),
            "layers": [Any](),
        ]
        guard let out = try? JSONSerialization.data(withJSONObject: wrapper),
              let string = String(data: out, encoding: .utf8) else { return }
        try? out.write(to: cacheURL)
        // Swapping the style mid-session reloads every layer; a fresh fetch only replaces a missing one.
        if json == nil { json = string }
    }

    static func patch(_ style: inout [String: Any]) {
        guard var layers = style["layers"] as? [[String: Any]] else { return }
        for i in layers.indices {
            switch layers[i]["id"] as? String {
            case "building-models": patchLandmarks(&layers[i])
            case "procedural-buildings": patchFacades(&layers[i])
            default: break
            }
        }
        style["layers"] = layers
    }

    /// Model layers don't resolve `config` expressions for these batched landmark models
    /// (they fall back to Standard's default), so landmarks get a literal tint. Models are lit
    /// darker than façades, hence warmer than the `colorBuildings` set in `CityStyle`.
    private static let landmarkWall = "#FCE5C0"

    private static func hsla(_ i: Int) -> [Any] { ["at", i, ["to-hsla", landmarkWall]] }

    /// Same window glass the landmark models use by day; warm lit windows at night.
    private static let glass: [Any] = [
        "match", ["config", "lightPreset"],
        "night", ["hsl", ["random", 0, 90, ["id"]], ["random", 20, 100, ["id"]], 87],
        ["hsl", ["random", 202, 214, ["id"]], ["random", 42, 55, ["id"]], ["random", 72, 79, ["id"]]],
    ]

    private static func patchLandmarks(_ layer: inout [String: Any]) {
        guard var paint = layer["paint"] as? [String: Any],
              var color = paint["model-color"] as? [Any] else { return }
        let roof: [Any] = [
            "let", "h", hsla(0), "s", hsla(1), "l", hsla(2),
            ["hsl", ["max", 0, ["-", ["var", "h"], 12]], ["var", "s"], ["max", 0, ["-", ["var", "l"], 3]]],
        ]
        let wall: [Any] = [
            "interpolate", ["linear"], ["measure-light", "brightness"],
            0, ["hsl", 29, 93, 77],
            0.2, landmarkWall,
        ]
        for i in color.indices {
            switch color[i] as? String {
            case "roof" where i + 1 < color.count: color[i + 1] = roof
            case "wall" where i + 1 < color.count: color[i + 1] = wall
            default: break
            }
        }
        // Most landmark meshes carry no `part` tag and land in the white catch-all branch.
        color[color.count - 1] = wall
        paint["model-color"] = color

        if var emissive = paint["model-emissive-strength"] as? [Any], emissive.count > 1 {
            emissive[emissive.count - 1] = ["interpolate", ["linear"], ["measure-light", "brightness"], 0.3, 0, 0.5, 0.15] as [Any]
            paint["model-emissive-strength"] = emissive
        }
        layer["paint"] = paint
    }

    private static func patchFacades(_ layer: inout [String: Any]) {
        guard var paint = layer["paint"] as? [String: Any] else { return }

        if var color = paint["building-color"] as? [Any],
           var body = color.last as? [Any],
           var parts = body.last as? [Any],
           let w = parts.firstIndex(where: { $0 as? String == "window" }), w + 1 < parts.count {
            parts[w + 1] = glass
            body[body.count - 1] = parts
            color[color.count - 1] = body
            paint["building-color"] = color
        }

        // A little daytime glow so façade glass reads lighter than the wall, like the landmarks' glass.
        if var emissive = paint["building-emissive-strength"] as? [Any],
           var parts = emissive.last as? [Any],
           let w = parts.firstIndex(where: { $0 as? String == "window" }), w + 1 < parts.count {
            parts[w + 1] = ["match", ["config", "lightPreset"], "night", ["random", 0, 0.2, ["id"]], ["random", 0.1, 0.25, ["id"]]] as [Any]
            emissive[emissive.count - 1] = parts
            paint["building-emissive-strength"] = emissive
        }
        layer["paint"] = paint
    }
}
