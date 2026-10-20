@_spi(Experimental) import MapboxMaps
import UIKit

/// Look test (`-pastelBlocks YES`): Altstadt buildings as plain extrusions, each in its own
/// pastel colour (OSM colour/material where known, a guess by type otherwise; ios/tools/pastel_blocks.py).
struct PastelBlocks: MapStyleContent {
    var body: some MapStyleContent {
        if let url = exploreBundle.url(forResource: "altstadt_pastel", withExtension: "geojson") {
            GeoJSONSource(id: "pastel-blocks")
                .data(.url(url))

            FillExtrusionLayer(id: "pastel-blocks", source: "pastel-blocks")
                .slot(.middle)
                .fillExtrusionColor(Exp(.toColor) { Exp(.get) { "color" } })
                .fillExtrusionHeight(Exp(.get) { "height" })
                .fillExtrusionBase(0)
                .fillExtrusionVerticalGradient(false)
                .fillExtrusionEdgeRadius(0.08)
                .fillExtrusionAmbientOcclusionIntensity(0.5)
                .fillExtrusionAmbientOcclusionRadius(3)
                .fillExtrusionCastShadows(true)
        }
    }
}

enum LookTest {
    static var pastelBlocks: Bool { UserDefaults.standard.bool(forKey: "pastelBlocks") }
}
