import Foundation
import MapboxMaps

private final class BundleToken {}

let exploreBundle = Bundle(for: BundleToken.self)

/// Our own stylised trees, instanced on every mapped OSM tree plus a scatter inside parks
/// (data baked by `ios/tools`). Replaces Mapbox Standard's built-in trees.
struct PuffyTrees: MapStyleContent {
    static let variants = ["tree_a", "tree_b", "tree_c", "bush_a"]

    var body: some MapStyleContent {
        if let url = exploreBundle.url(forResource: "frankfurt_trees", withExtension: "geojson") {
            GeoJSONSource(id: "puffy-trees")
                .data(.url(url))

            ForEvery(Self.variants, id: \.self) { name in
                if let model = exploreBundle.url(forResource: name, withExtension: "glb") {
                    Model(id: name, uri: model)
                }
            }

            ModelLayer(id: "puffy-trees", source: "puffy-trees")
                .slot(.middle)
                .minZoom(13.5)
                .modelId(Exp(.get) { "m" })
                .modelType(.common3d)
                .modelScale(x: 1.15, y: 1.15, z: 1.15)
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
