import Foundation

/// Real roof shapes and façade/roof colours from OSM (`ios/tools/bake_building_tags.py`), folded
/// into Standard's procedural building layer as `match` expressions on the feature id, which is
/// the OSM way id.
///
/// Tried and dropped: a second procedural layer on Streets' building data for the buildings
/// Standard draws flat. It renders, but without windows or roof shapes (those need the
/// procedural tileset), and it hides any extrusion under its footprint.
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
    /// OSM wall colours present in the data (for building façade images).
    static var wallColours: [String] { (tags?.wall.keys).map { Array($0).sorted() } ?? [] }

    static func byID(_ groups: [String: [Int]], value: (String) -> Any = { $0 }, fallback: Any) -> Any {
        var seen = Set<Int>()
        var args: [Any] = ["match", ["id"]]
        for (key, ids) in groups.sorted(by: { $0.key < $1.key }) {
            let fresh = ids.filter { seen.insert($0).inserted }
            guard !fresh.isEmpty else { continue }
            args.append(fresh)
            args.append(value(key))
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

    // MARK: Lookups for on-device geometry (`RoofBuilder`)

    private static let roofByID: [Int: String] = {
        var out: [Int: String] = [:]
        for (shape, ids) in tags?.roof ?? [:] { for i in ids { out[i] = shape } }
        return out
    }()

    private static let roofColourByID: [Int: String] = {
        var out: [Int: String] = [:]
        for (c, ids) in tags?.roofColour ?? [:] { for i in ids { out[i] = c } }
        return out
    }()

    /// Roof shape our plain buildings get: OSM's where mapped, else houses up to 22 m get a gabled
    /// (two in three) or hipped roof, everything else flat. Must match `pitchedExp`.
    static func roofShape(id: Int, height: Double) -> String {
        if let s = roofByID[id] { return s }
        guard height <= 22 else { return "flat" }
        return id % 3 == 0 ? "hipped" : "gabled"
    }

    static func roofColour(id: Int) -> String? { roofColourByID[id] }

    /// True for plain buildings that get a pitched roof from `RoofBuilder` (same rule as above).
    static var pitchedExp: Any {
        let roofs = tags?.roof ?? [:]
        let pitched = roofs.filter { $0.key != "flat" }.flatMap(\.value)
        let flat = roofs["flat"] ?? []
        func among(_ ids: [Int]) -> Any { ids.isEmpty ? false : ["match", ["id"], ids, true, false] as [Any] }
        return ["any", among(pitched), ["all", ["<=", ["get", "height"], 22], ["!", among(flat)]]] as [Any]
    }

    static func wallColour(fallback: Any) -> Any { byID(tags?.wall ?? [:], fallback: fallback) }
    static func wallImage(_ name: (String) -> String, fallback: Any) -> Any {
        byID(tags?.wall ?? [:], value: name, fallback: fallback)
    }
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
}
