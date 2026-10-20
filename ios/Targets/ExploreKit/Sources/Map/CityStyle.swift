import MapboxMaps
import UIKit

enum CityStyle {

    /// Uses the patched Standard (see `Basemap`) when available, plain Standard otherwise.
    static func mapStyle(for mood: MapMood, palette: CityPalette, basemap: String?) -> MapStyle {
        if let basemap {
            MapStyle(json: basemap, configuration: configuration(mood, palette))
        } else {
            MapStyle(uri: .standard, configuration: configuration(mood, palette))
        }
    }

    private static func configuration(_ mood: MapMood, _ p: CityPalette) -> JSONObject {
        let ownBuildings = UserDefaults.standard.bool(forKey: "toyExtrusions") || LookTest.pastelBlocks
        return [
            "theme": "default",
            "lightPreset": .string(lightPreset(mood)),
            "font": "Rubik",
            "showPointOfInterestLabels": true,
            "showTransitLabels": false,
            "showPedestrianRoads": true,
            "show3dObjects": true,
            "backgroundPointOfInterestLabels": "circle",
            "colorBuildings": .string(p.buildings.hexString),
            "colorGreenspace": .string(p.green.hexString),
            "colorLand": .string(p.land.hexString),
            "colorMotorways": .string(p.trunks.hexString),
            "colorPlaceLabels": "#3B3F63",
            "colorRoadLabels": "#6E6F86",
            "colorRoads": .string(p.roads.hexString),
            "colorHdRoads": .string(p.roads.hexString),
            "colorCommercial": .string(p.landuse.hexString),
            "colorEducation": .string(p.landuse.hexString),
            "colorMedical": .string(p.landuse.hexString),
            "colorIndustrial": .string(p.landuse.hexString),
            "colorTrunks": .string(p.trunks.hexString),
            "colorWater": .string(p.water.hexString),
            "densityPointOfInterestLabels": 1.4,
            "show3dBuildings": .boolean(!ownBuildings),
            "show3dFacades": .boolean(!ownBuildings),
            "show3dLandmarks": true,
            "show3dTrees": false,
            "showLandmarkIconLabels": true,
            "showLandmarkIcons": true,
        ]
    }

    private static func lightPreset(_ mood: MapMood) -> String {
        switch mood {
        case .day: "day"
        case .dawn: "dawn"
        case .dusk: "dusk"
        case .night: "night"
        }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}
