import MapKit
import SwiftUI

/// Debug view: Apple's own MapKit 3D at a given spot, to compare against the reference look.
/// Launch with `-mapkit london|buckingham|frankfurt`.
public struct MapKitProbe: View {
    let spot: String
    @State private var position: MapCameraPosition

    public init(spot: String) {
        self.spot = spot
        let cams: [String: MapCamera] = [
            "london": MapCamera(centerCoordinate: .init(latitude: 51.5052, longitude: -0.1500), distance: 650, heading: 20, pitch: 62),
            "buckingham": MapCamera(centerCoordinate: .init(latitude: 51.5014, longitude: -0.1419), distance: 1400, heading: 0, pitch: 55),
            "frankfurt": MapCamera(centerCoordinate: .init(latitude: 50.1107, longitude: 8.6822), distance: 650, heading: -18, pitch: 62),
        ]
        _position = State(initialValue: .camera(cams[spot] ?? cams["london"]!))
    }

    public var body: some View {
        Map(position: $position)
            .mapStyle(.standard(elevation: .realistic, emphasis: .automatic, pointsOfInterest: .all, showsTraffic: false))
            .ignoresSafeArea()
    }
}
