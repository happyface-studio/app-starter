import MapboxMaps
import UIKit

enum CityStyle {

    /// Uses the patched Standard (see `Basemap`) when available, plain Standard otherwise.
    static func mapStyle(for mood: MapMood, basemap: String?) -> MapStyle {
        if let basemap {
            MapStyle(json: basemap, configuration: configuration(mood))
        } else {
            MapStyle(uri: .standard, configuration: configuration(mood))
        }
    }

    private static func configuration(_ mood: MapMood) -> JSONObject {
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
            "colorBuildings": "#F7E9CF",
            "colorGreenspace": "#8CCB5E",
            "colorLand": "#F2EADF",
            "colorMotorways": "#C98F92",
            "colorPlaceLabels": "#3B3F63",
            "colorRoadLabels": "#6E6F86",
            "colorRoads": "#DDB3B5",
            "colorTrunks": "#C98F92",
            "colorWater": "#62B4EC",
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
