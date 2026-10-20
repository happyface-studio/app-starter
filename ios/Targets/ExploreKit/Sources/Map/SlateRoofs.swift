@_spi(Experimental) import MapboxMaps
import UIKit

/// Slate-blue caps on top of Standard's 3D buildings, so the whole city reads as cream walls
/// with blue roofs. Rounded edges make each cap read as a soft, sloped toy roof.
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
                Exp(.gt) { Exp(.get) { "height" }; 4 }
            })
            .fillExtrusionColor(UIColor(hex: 0x6472BE))
            .fillExtrusionBase(Exp(.sum) { Exp(.get) { "height" }; -0.4 })
            .fillExtrusionHeight(Exp(.sum) { Exp(.get) { "height" }; 2.2 })
            .fillExtrusionEdgeRadius(0.6)
            .fillExtrusionRoundedRoof(true)
            .fillExtrusionCastShadows(true)
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
