import MapboxMaps
import UIKit

/// Slate-blue caps on the simple `FarBuildings` extrusions outside the baked Altstadt,
/// so the rest of the city keeps the cream-walls-blue-roofs read.
struct SlateRoofs: MapStyleContent {
    var body: some MapStyleContent {
        FillExtrusionLayer(id: "slate-roofs", source: "far-buildings")
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(14.5)
            .filter(Altstadt.outsideFilter)
            .fillExtrusionColor(UIColor(hex: 0x6472BE))
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
