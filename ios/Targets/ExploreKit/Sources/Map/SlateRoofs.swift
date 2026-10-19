import MapboxMaps
import UIKit

/// Thin slate-blue caps sitting on top of Standard's 3D buildings, so the city reads as
/// cream walls with blue roofs. Standard has a single building colour, so roofs need their own layer.
struct SlateRoofs: MapStyleContent {
    var body: some MapStyleContent {
        VectorSource(id: "roof-buildings")
            .url("mapbox://mapbox.mapbox-streets-v8")

        FillExtrusionLayer(id: "slate-roofs", source: "roof-buildings")
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(14.5)
            .filter(Exp(.all) {
                Exp(.eq) { Exp(.get) { "extrude" }; "true" }
                Exp(.gt) { Exp(.get) { "height" }; 3 }
            })
            .fillExtrusionColor(UIColor(hex: 0x6F78B5))
            .fillExtrusionBase(Exp(.sum) { Exp(.get) { "height" }; 0.15 })
            .fillExtrusionHeight(Exp(.sum) { Exp(.get) { "height" }; 1.1 })
            .fillExtrusionOpacity(Exp(.interpolate) {
                Exp(.linear)
                Exp(.zoom)
                14.5
                0
                15.2
                1
            })
            .fillExtrusionAmbientOcclusionIntensity(0.3)
    }
}
