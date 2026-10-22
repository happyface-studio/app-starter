import Foundation
import MapboxMaps

private final class BundleToken {}

let exploreBundle = Bundle(for: BundleToken.self)

/// Our own stylised trees, instanced on every mapped OSM tree plus a scatter inside parks
/// (data baked by `ios/tools`). Replaces Mapbox Standard's built-in trees.
struct PuffyTrees: MapStyleContent {
    var season: Season = .summer

    static func model(_ name: String) -> URL? {
        exploreBundle.url(forResource: name, withExtension: "glb")
    }

    var body: some MapStyleContent {
        if let url = exploreBundle.url(forResource: "frankfurt_trees", withExtension: "geojson") {
            GeoJSONSource(id: "puffy-trees")
                .data(.url(url))

            // Only the current season's set is registered; ids stay the plain names.
            Model(id: "tree_a", uri: Self.model("tree_a" + season.modelSuffix))
            Model(id: "tree_b", uri: Self.model("tree_b" + season.modelSuffix))
            Model(id: "tree_c", uri: Self.model("tree_c" + season.modelSuffix))
            Model(id: "bush_a", uri: Self.model("bush_a" + season.modelSuffix))

            ModelLayer(id: "puffy-trees", source: "puffy-trees")
                .slot(.middle)
                .minZoom(13.5)
                .modelId(Exp(.get) { "m" })
                .modelType(.common3d)
                .modelScale(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.zoom)
                    14
                    [2.6, 2.6, 2.6]
                    17
                    [1.9, 1.9, 1.9]
                })
                .modelCastShadows(true)
                .modelReceiveShadows(true)
                .modelAmbientOcclusionIntensity(0.9)
                .modelOpacity(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.zoom)
                    13.5
                    0
                    14.2
                    1
                })
        }
    }
}
