import Foundation

/// Real roof shapes and façade/roof colours from OSM (`ios/tools/bake_building_tags.py`), folded
/// into Standard's procedural building layer as `match` expressions on the feature id, which is
/// the OSM way id. Also builds the extra procedural layer that gives every other building the
/// same windows and roofs as the centre, instead of a flat extrusion.
enum BuildingLook {
    private struct Tags: Decodable {
        var roof: [String: [Int]]
        var wall: [String: [Int]]
        var roofColour: [String: [Int]]
    }

    private static let tags: Tags? = {
        guard let url = exploreBundle.url(forResource: "frankfurt_building_tags", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Tags.self, from: data)
    }()

    /// `["match", ["id"], [ids], value, …, fallback]`, or the fallback alone if there's no data.
    private static func byID(_ groups: [String: [Int]], fallback: Any) -> Any {
        var seen = Set<Int>()
        var args: [Any] = ["match", ["id"]]
        for (value, ids) in groups.sorted(by: { $0.key < $1.key }) {
            let fresh = ids.filter { seen.insert($0).inserted }
            guard !fresh.isEmpty else { continue }
            args.append(fresh)
            args.append(value)
        }
        guard args.count > 2 else { return fallback }
        args.append(fallback)
        return args
    }

    /// The building's mapped roof shape, else `fallback`. Tiny towers stay flat as before.
    static func roofShape(fallback: Any) -> Any {
        let mapped = byID(tags?.roof ?? [:], fallback: fallback)
        return ["case", ["all", ["<=", ["get", "area"], 200], [">=", ["get", "height"], 100]], "flat", mapped] as [Any]
    }

    /// `-restBuildings NO` falls back to our flat window-pattern extrusions (`PlainBuildings`).
    static let restEnabled = UserDefaults.standard.object(forKey: "restBuildings") == nil || UserDefaults.standard.bool(forKey: "restBuildings")

    static func wallColour(fallback: Any) -> Any { byID(tags?.wall ?? [:], fallback: fallback) }
    static func roofColour(fallback: Any) -> Any { byID(tags?.roofColour ?? [:], fallback: fallback) }

    /// Replaces the value for `part` in the `["match", ["get", "building-part"], …]` inside
    /// Standard's building-color (`let … case … match`).
    static func editPart(_ part: String, in color: inout [Any], _ edit: (Any) -> Any) {
        guard var body = color.last as? [Any], var parts = body.last as? [Any],
              let i = parts.firstIndex(where: { $0 as? String == part }), i + 1 < parts.count else { return }
        parts[i + 1] = edit(parts[i + 1])
        body[body.count - 1] = parts
        color[color.count - 1] = body
    }

    /// A copy of the patched procedural layer for the buildings it leaves out (Standard draws those
    /// as flat extrusions). Houses get a gabled or hipped roof unless OSM says otherwise, each
    /// building one of the varied wall tones, and a little height variation so terraces read as
    /// separate houses.
    static func rest(from procedural: [String: Any], palette p: CityPalette) -> [String: Any] {
        var layer = procedural
        layer["id"] = "procedural-buildings-rest"
        // The procedural tileset only carries the buildings Standard draws procedurally; the rest
        // are in Streets' building layer (what Standard's flat `3d-building` layer draws).
        layer["source"] = "composite"
        layer["source-layer"] = "building"
        layer["filter"] = ["all", ["==", ["get", "extrude"], "true"], ["==", ["get", "underground"], "false"]] as [Any]

        var layout = layer["layout"] as? [String: Any] ?? [:]
        let house: [Any] = ["all", ["<=", ["get", "height"], 25], ["<=", ["get", "area"], 500]]
        let houseRoof: [Any] = ["case", ["==", ["%", ["to-number", ["id"], 0], 3], 0], "hipped", "gabled"]
        layout["building-roof-shape"] = roofShape(fallback: ["case", house, houseRoof, "parapet"] as [Any])
        layout["building-height"] = ["+", ["coalesce", ["get", "est_height"], ["get", "height"]], ["random", 0, 1.8, ["id"]]] as [Any]
        let wall: [Any] = ["-", ["get", "height"], ["coalesce", ["get", "min_height"], 0]]
        layout["building-facade"] = [">=", wall, 4] as [Any]
        layout["building-facade-floors"] = ["max", 1, ["round", ["/", wall, 3.4]]] as [Any]
        layout["building-facade-window"] = ["literal", [0.5, 0.7]] as [Any]
        layout["building-facade-unit-width"] = ["random", 2.8, 3.8, ["id"]] as [Any]
        layer["layout"] = layout

        var paint = layer["paint"] as? [String: Any] ?? [:]
        if var color = paint["building-color"] as? [Any] {
            let tones = (0..<FacadeTile.tones).map { FacadeTile.wall(p, tone: $0).cssHex }
            let mixed: [Any] = ["to-color", ["at", ["%", ["to-number", ["id"], 0], Double(tones.count)], ["literal", tones]]]
            editPart("wall", in: &color) { _ in wallColour(fallback: mixed) }
            paint["building-color"] = color
        }
        layer["paint"] = paint
        return layer
    }
}
