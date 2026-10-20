import MapboxMaps
import UIKit

/// Buildings Standard draws without façades, redrawn with the palette's window pattern on the
/// walls (`FacadeTile`) and a thin slate cap as the roof. Mapbox hides these footprints wherever
/// a façade building or landmark covers them, as it did for Standard's own plain layer.
struct PlainBuildings: MapStyleContent {
    var palette: CityPalette

    private static let source = "plain-buildings"

    private static let extruded = Exp(.all) {
        Exp(.eq) { Exp(.get) { "extrude" }; "true" }
        Exp(.eq) { Exp(.get) { "underground" }; "false" }
    }

    private static let height = Exp(.number) { Exp(.get) { "height" } }

    private static var base: Exp {
        Exp(.max) { 0; Exp(.coalesce) { Exp(.get) { "min_height" }; 0 } }
    }

    private static var fadeIn: Exp {
        Exp(.interpolate) {
            Exp(.linear)
            Exp(.zoom)
            15
            0
            15.3
            1
        }
    }

    private var roof: UIColor {
        UIColor(hex: palette.roof ?? palette.buildings)
    }

    var body: some MapStyleContent {
        VectorSource(id: Self.source)
            .url("mapbox://mapbox.mapbox-streets-v8")

        FillExtrusionLayer(id: "plain-buildings", source: Self.source)
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(15)
            .filter(Self.extruded)
            .fillExtrusionPattern(FacadeTile.imageID(palette))
            .fillExtrusionHeight(Self.height)
            .fillExtrusionBase(Self.base)
            .fillExtrusionOpacity(Self.fadeIn)
            .fillExtrusionVerticalGradient(false)
            .fillExtrusionAmbientOcclusionIntensity(0.3)
            .fillExtrusionCastShadows(true)

        FillExtrusionLayer(id: "plain-buildings-roof", source: Self.source)
            .sourceLayer("building")
            .slot(.middle)
            .minZoom(15)
            .filter(Self.extruded)
            .fillExtrusionColor(StyleColor(roof))
            .fillExtrusionBase(Self.height)
            .fillExtrusionHeight(Exp(.sum) { Self.height; 0.4 })
            .fillExtrusionOpacity(Self.fadeIn)
            .fillExtrusionVerticalGradient(false)
            .fillExtrusionCastShadows(false)
    }
}
