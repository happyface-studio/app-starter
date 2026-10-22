import Foundation
import MapboxMaps
import Observation

/// Mapbox Standard, patched so landmark models and ordinary buildings read as one city:
/// landmark walls/roofs get the palette's tint (Standard hard-codes them white/peach), and all
/// windows get the palette's glass instead of Standard's desaturated wall colour.
///
/// Standard's layer paint can't be changed through the import API, so we fetch the style JSON,
/// patch the two layers and re-import it inline under the id `basemap` — config still applies.
@Observable
@MainActor
final class Basemap {
    static let shared = Basemap()

    private(set) var isResolved = false
    private var standard: [String: Any]?
    @ObservationIgnored private var patched: [String: String] = [:]

    private let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("standard-v1.json")

    private init() {
        if let data = try? Data(contentsOf: cacheURL),
           let style = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            standard = style
            isResolved = true
        }
        Task { await refresh() }
    }

    func json(for palette: CityPalette) -> String? {
        if let cached = patched[palette.id] { return cached }
        guard var style = standard else { return nil }
        Self.patch(&style, palette: palette)
        let wrapper: [String: Any] = [
            "version": 8,
            "imports": [["id": "basemap", "url": "mapbox://styles/mapbox/standard", "data": style]],
            "sources": [String: Any](),
            "layers": [Any](),
        ]
        guard let out = try? JSONSerialization.data(withJSONObject: wrapper),
              let string = String(data: out, encoding: .utf8) else { return nil }
        patched[palette.id] = string
        return string
    }

    private func refresh() async {
        defer { isResolved = true }
        let token = MapboxOptions.accessToken
        guard !token.isEmpty,
              let url = URL(string: "https://api.mapbox.com/styles/v1/mapbox/standard?access_token=\(token)"),
              let result = try? await URLSession.shared.data(from: url),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let style = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any]
        else { return }
        try? result.0.write(to: cacheURL)
        // Swapping the style mid-session reloads every layer; a fresh fetch only fills a missing one.
        if standard == nil { standard = style }
    }

    static func patch(_ style: inout [String: Any], palette: CityPalette) {
        guard var layers = style["layers"] as? [[String: Any]] else { return }
        for i in layers.indices {
            guard let id = layers[i]["id"] as? String else { continue }
            switch id {
            case "building-models": patchLandmarks(&layers[i], palette)
            case "procedural-buildings": patchFacades(&layers[i], palette)
            default: patchStreets(&layers[i], id: id, palette)
            }
        }
        if let i = layers.firstIndex(where: { $0["id"] as? String == "3d-building" }) {
            patchPlainBuildings(&layers, at: i, palette)
        }
        style["layers"] = layers
        patchDaylight(&style)
    }

    /// Standard's day light is 80% flat ambient with a weak sun almost overhead, which washes the
    /// toy look out. Use a lower, stronger sun by day so walls and tree crowns get real shading.
    /// Other presets keep Standard's values.
    private static func patchDaylight(_ style: inout [String: Any]) {
        guard var lights = style["lights"] as? [[String: Any]] else { return }
        func byDay(_ day: Any, _ other: Any?) -> Any {
            ["match", ["config", "lightPreset"], "day", day, other ?? day] as [Any]
        }
        for i in lights.indices {
            guard var props = lights[i]["properties"] as? [String: Any] else { continue }
            switch lights[i]["type"] as? String {
            case "ambient":
                props["intensity"] = byDay(0.58, props["intensity"])
            case "directional":
                props["intensity"] = byDay(0.55, props["intensity"])
                props["direction"] = byDay(["literal", [205, 42]] as [Any], props["direction"])
            default: break
            }
            lights[i]["properties"] = props
        }
        style["lights"] = lights
    }

    /// Buildings without façade data use a plain extrusion layer with no roof colour and no
    /// windows, and patterns can't reach into the import. `PlainBuildings` redraws them in the
    /// root style with windows and slate roofs, so the imported layer is switched off.
    private static func patchPlainBuildings(_ layers: inout [[String: Any]], at i: Int, _ p: CityPalette) {
        var layout = layers[i]["layout"] as? [String: Any] ?? [:]
        layout["visibility"] = "none"
        layers[i]["layout"] = layout
    }

    private static let footways = ["path", "pedestrian", "steps"]

    /// Standard draws footpaths and plazas in fixed lilac-grey with grey outlines (a wireframe
    /// look over the Altstadt) and tram rails with sleepers. Fold them into the palette instead.
    private static func patchStreets(_ layer: inout [String: Any], id: String, _ p: CityPalette) {
        let isFootway = footways.contains { id.hasSuffix("-\($0)") || id.hasSuffix("-\($0)-case") }
            && ["road-", "bridge-", "tunnel-"].contains { id.hasPrefix($0) }

        if (isFootway && id.hasSuffix("-case")) || id.hasSuffix("rail-tracks") {
            var layout = layer["layout"] as? [String: Any] ?? [:]
            layout["visibility"] = "none"
            layer["layout"] = layout
            return
        }

        var paint = layer["paint"] as? [String: Any] ?? [:]
        if isFootway {
            paint["line-color"] = p.paving.hexString
        } else if id == "road-pedestrian-polygon-fill" {
            paint["fill-color"] = p.paving.hexString
        } else if id.hasSuffix("rail") {
            paint["line-color"] = p.curb.hexString
            paint["line-opacity"] = 0.7
        } else if id == "roads-case" || id == "road-polygon-case" || id == "tunnel-roads-case" {
            paint["line-color"] = p.curb.hexString
        } else {
            return
        }
        layer["paint"] = paint
    }

    private static func dayGlass(_ p: CityPalette) -> [Any] {
        let g = p.glass
        return [
            "hsl",
            ["random", g.hue.lowerBound, g.hue.upperBound, ["id"]],
            ["random", g.saturation.lowerBound, g.saturation.upperBound, ["id"]],
            ["random", g.lightness.lowerBound, g.lightness.upperBound, ["id"]],
        ]
    }

    /// A roof colour with a little per-building lightness jitter, so roofscapes don't read as one sheet.
    private static func slate(_ hex: UInt32) -> [Any] {
        let c: [Any] = ["to-hsla", hex.hexString]
        return [
            "hsl", ["at", 0, c], ["at", 1, c],
            ["random", ["max", 0, ["-", ["at", 2, c], 2]], ["min", 100, ["+", ["at", 2, c], 2]], ["id"]],
        ]
    }

    private static let nightGlass: [Any] = ["hsl", ["random", 0, 90, ["id"]], ["random", 20, 100, ["id"]], 87]

    /// Model layers don't resolve `config` expressions for these batched landmark models
    /// (they fall back to Standard's defaults), so everything here keys off measured light.
    private static func patchLandmarks(_ layer: inout [String: Any], _ p: CityPalette) {
        guard var paint = layer["paint"] as? [String: Any],
              var color = paint["model-color"] as? [Any] else { return }
        let tint = p.landmark.hexString
        let hsla: (Int) -> [Any] = { ["at", $0, ["to-hsla", tint]] }
        let roof: [Any] = (p.landmarkRoof ?? p.roof).map(slate) ?? [
            "let", "h", hsla(0), "s", hsla(1), "l", hsla(2),
            ["hsl", ["max", 0, ["-", ["var", "h"], 12]], ["var", "s"], ["max", 0, ["-", ["var", "l"], 3]]],
        ]
        let wall: [Any] = ["interpolate", ["linear"], ["measure-light", "brightness"], 0, ["hsl", 29, 93, 77], 0.2, tint]
        let window: [Any] = ["interpolate", ["linear"], ["measure-light", "brightness"], 0, nightGlass, 0.15, dayGlass(p)]
        for i in color.indices {
            switch color[i] as? String {
            case "roof" where i + 1 < color.count: color[i + 1] = roof
            case "wall" where i + 1 < color.count: color[i + 1] = wall
            case "window" where i + 1 < color.count: color[i + 1] = window
            default: break
            }
        }
        // Most landmark meshes carry no `part` tag and land in the white catch-all branch.
        color[color.count - 1] = wall
        paint["model-color"] = color

        if var emissive = paint["model-emissive-strength"] as? [Any], emissive.count > 1 {
            emissive[emissive.count - 1] = ["interpolate", ["linear"], ["measure-light", "brightness"], 0.3, 0, 0.5, 0.15] as [Any]
            // Glow washes slate roofs out to grey; walls keep it so they match façade brightness.
            if p.roof != nil { emissive.insert(contentsOf: ["roof", 0] as [Any], at: emissive.count - 1) }
            paint["model-emissive-strength"] = emissive
        }
        layer["paint"] = paint
    }

    private static func patchFacades(_ layer: inout [String: Any], _ p: CityPalette) {
        // Standard only gives building parts (`building_id`) windows above 100 m, which leaves most
        // multi-part buildings blank. Any wall of 4 m or more gets windows, one floor per ~3.6 m.
        if var layout = layer["layout"] as? [String: Any] {
            let wall: [Any] = ["-", ["get", "height"], ["coalesce", ["get", "min_height"], 0]]
            layout["building-facade"] = [">=", wall, 4] as [Any]
            if var floors = layout["building-facade-floors"] as? [Any],
               var cases = floors[1] as? [Any], cases.count > 2 {
                cases[2] = ["/", wall, 3.6] as [Any]
                floors[1] = cases
                layout["building-facade-floors"] = floors
            }
            layer["layout"] = layout
        }

        guard var paint = layer["paint"] as? [String: Any] else { return }

        if var color = paint["building-color"] as? [Any],
           var body = color.last as? [Any],
           var parts = body.last as? [Any],
           let w = parts.firstIndex(where: { $0 as? String == "window" }), w + 1 < parts.count {
            parts[w + 1] = ["match", ["config", "lightPreset"], "night", nightGlass, dayGlass(p)] as [Any]
            if let roof = p.roof, let r = parts.firstIndex(where: { $0 as? String == "roof" }), r + 1 < parts.count {
                parts[r + 1] = slate(roof)
            }
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
