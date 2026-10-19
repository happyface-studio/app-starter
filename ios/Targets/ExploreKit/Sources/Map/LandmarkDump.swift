import CoreLocation
import Foundation
import MapboxMaps
import SwiftUI

/// Debug tool (`-dumpLandmarks YES`): walks the camera over the Altstadt, queries Standard's
/// building featureset and writes every feature (group, id, footprint) to Documents/landmarks.json.
/// The bake reads that file to leave out OSM buildings that Mapbox already models by hand.
@MainActor
enum LandmarkDump {
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: "dumpLandmarks") }

    static func run(map: MapboxMap, setCamera: @escaping (CameraOptions) -> Void) {
        let lats = stride(from: Altstadt.south + 0.0012, through: Altstadt.north - 0.0012, by: 0.0024).map { $0 }
        let lons = stride(from: Altstadt.west + 0.0018, through: Altstadt.east - 0.0018, by: 0.0036).map { $0 }
        var stops: [CLLocationCoordinate2D] = []
        for lat in lats { for lon in lons { stops.append(.init(latitude: lat, longitude: lon)) } }
        var collected: [String: [String: Any]] = [:]

        func step(_ i: Int) {
            guard i < stops.count else {
                write(collected)
                return
            }
            setCamera(CameraOptions(center: stops[i], zoom: 16.4, bearing: 0, pitch: 0))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                let rect = CGRect(x: 0, y: 0, width: 402, height: 874)
                map.queryRenderedFeatures(with: rect, featureset: .standardBuildings) { result in
                    if case .success(let features) = result {
                        for f in features {
                            guard let json = try? JSONEncoder().encode(f.geometry),
                                  let geom = try? JSONSerialization.jsonObject(with: json) else { continue }
                            let key = f.id.map { "\($0.id)" } ?? UUID().uuidString
                            collected[key] = [
                                "group": f.group ?? "",
                                "height": f.height ?? 0,
                                "props": f.properties.compactMapValues { $0.map { "\($0)" } },
                                "geometry": geom,
                            ]
                        }
                    }
                    step(i + 1)
                }
            }
        }
        step(0)
    }

    private static func write(_ collected: [String: [String: Any]]) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("landmarks.json")
        if let data = try? JSONSerialization.data(withJSONObject: Array(collected.values), options: [.prettyPrinted]) {
            try? data.write(to: url)
            print("LANDMARK_DUMP_DONE \(collected.count) \(url.path)")
        }
    }
}
