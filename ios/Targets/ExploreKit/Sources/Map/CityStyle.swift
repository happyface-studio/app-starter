import MapboxMaps
import UIKit

enum CityStyle {

    static func mapStyle(for mood: MapMood) -> MapStyle {
        .standard(
            theme: .default,
            lightPreset: lightPreset(mood),
            font: .rubik,
            showPointOfInterestLabels: true,
            showTransitLabels: false,
            showPedestrianRoads: true,
            show3dObjects: true,
            backgroundPointOfInterestLabels: .circle,
            colorBuildings: StyleColor(UIColor(hex: 0xF0DAB2)),
            colorGreenspace: StyleColor(UIColor(hex: 0x86C45B)),
            colorLand: StyleColor(UIColor(hex: 0xF4E9D6)),
            colorMotorways: StyleColor(UIColor(hex: 0xC98F92)),
            colorPlaceLabels: StyleColor(UIColor(hex: 0x3B3F63)),
            colorRoadLabels: StyleColor(UIColor(hex: 0x6E6F86)),
            colorRoads: StyleColor(UIColor(hex: 0xD7A5A6)),
            colorTrunks: StyleColor(UIColor(hex: 0xC98F92)),
            colorWater: StyleColor(UIColor(hex: 0x5AB0EA)),
            densityPointOfInterestLabels: 1.4,
            show3dBuildings: true,
            show3dFacades: true,
            show3dLandmarks: true,
            show3dTrees: false,
            showLandmarkIconLabels: true,
            showLandmarkIcons: true
        )
    }

    private static func lightPreset(_ mood: MapMood) -> StandardLightPreset {
        switch mood {
        case .day: .day
        case .dawn: .dawn
        case .dusk: .dusk
        case .night: .night
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
