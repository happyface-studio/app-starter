import CoreLocation
import Foundation
import MapboxMaps
import SwiftUI
import UIKit

/// Debug tool (`-landmarkMask YES`): renders only Mapbox Standard's hand-made landmark models,
/// top-down over a flat magenta ground, and saves snapshots plus their corner coordinates to
/// Documents/landmark_mask/. `ios/tools/landmark_mask.py` turns them into a list of OSM buildings
/// the bake leaves out, so Mapbox's landmark architecture stays visible.
@MainActor
enum LandmarkMask {
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: "landmarkMask") }

    static let magenta = StyleColor(UIColor(red: 1, green: 0, blue: 1, alpha: 1))

    static var style: MapStyle {
        .standard(
            theme: .default, lightPreset: .day,
            showPointOfInterestLabels: false, showTransitLabels: false, showPlaceLabels: false,
            showRoadLabels: false, showPedestrianRoads: false, show3dObjects: true,
            colorAdminBoundaries: magenta, colorBuildings: magenta, colorCommercial: magenta,
            colorEducation: magenta, colorGreenspace: magenta, colorIndustrial: magenta,
            colorLand: magenta, colorMedical: magenta, colorMotorways: magenta,
            colorRoads: magenta, colorTrunks: magenta, colorWater: magenta,
            show3dBuildings: false, show3dFacades: false, show3dLandmarks: true, show3dTrees: false,
            showAdminBoundaries: false, showLandmarkIconLabels: false, showLandmarkIcons: false
        )
    }

    static func run(proxy: MapProxy) {
        guard let map = proxy.map else { return }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("landmark_mask", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var stops: [CLLocationCoordinate2D] = []
        for lat in stride(from: Altstadt.south + 0.0016, through: Altstadt.north, by: 0.0030) {
            for lon in stride(from: Altstadt.west + 0.0012, through: Altstadt.east, by: 0.0022) {
                stops.append(.init(latitude: lat, longitude: lon))
            }
        }
        var index: [[String: Any]] = []

        func step(_ i: Int) {
            guard i < stops.count else {
                let data = try? JSONSerialization.data(withJSONObject: index, options: .prettyPrinted)
                try? data?.write(to: dir.appendingPathComponent("index.json"))
                print("LANDMARK_MASK_DONE \(index.count)")
                return
            }
            map.setCamera(to: CameraOptions(center: stops[i], zoom: 16.4, bearing: 0, pitch: 0))
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                guard let image = proxy.captureSnapshot(), let png = image.pngData() else { return step(i + 1) }
                let name = "tile_\(i).png"
                try? png.write(to: dir.appendingPathComponent(name))
                let size = image.size
                func corner(_ x: CGFloat, _ y: CGFloat) -> [Double] {
                    let c = map.coordinate(for: CGPoint(x: x, y: y))
                    return [c.longitude, c.latitude]
                }
                index.append([
                    "file": name, "width_pt": size.width, "height_pt": size.height, "scale": image.scale,
                    "tl": corner(0, 0), "tr": corner(size.width, 0), "bl": corner(0, size.height), "br": corner(size.width, size.height),
                ])
                step(i + 1)
            }
        }
        step(0)
    }
}
