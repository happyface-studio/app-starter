import MapboxMaps
import QuartzCore

/// Pushes moving features to a GeoJSON source as partial updates (add / update / remove by id)
/// instead of replacing the whole collection, and at a capped rate. Replacing the collection makes
/// Mapbox re-parse and re-tile everything each time, which is what made panning stutter.
@MainActor
final class LiveSource {
    let id: String
    /// Updates per second while the camera is still, and while the user is moving it.
    let rate: Double
    let movingRate: Double

    private var published: Set<String> = []
    private var lastPublish: CFTimeInterval = 0
    private var lastCamera: CameraState?

    init(_ id: String, rate: Double, movingRate: Double? = nil) {
        self.id = id
        self.rate = rate
        self.movingRate = movingRate ?? rate / 2
    }

    /// Whether it's time to publish again. Cheap: call every frame, build features only when true.
    func due(_ map: MapboxMap, now: CFTimeInterval = CACurrentMediaTime()) -> Bool {
        let camera = map.cameraState
        let moving = map.isGestureInProgress || lastCamera.map { $0 != camera } ?? false
        lastCamera = camera
        return now - lastPublish >= 1 / (moving ? movingRate : rate)
    }

    /// Features must carry a string identifier.
    func publish(_ features: [Feature], map: MapboxMap) {
        lastPublish = CACurrentMediaTime()
        var ids = Set<String>()
        ids.reserveCapacity(features.count)
        var added: [Feature] = [], updated: [Feature] = []
        for f in features {
            guard case .string(let fid)? = f.identifier else { continue }
            ids.insert(fid)
            if published.contains(fid) { updated.append(f) } else { added.append(f) }
        }
        let removed = published.subtracting(ids)
        if !removed.isEmpty { map.removeGeoJSONSourceFeatures(forSourceId: id, featureIds: Array(removed)) }
        if !added.isEmpty { map.addGeoJSONSourceFeatures(forSourceId: id, features: added) }
        if !updated.isEmpty { map.updateGeoJSONSourceFeatures(forSourceId: id, features: updated) }
        published = ids
    }

    func clear(map: MapboxMap) {
        guard !published.isEmpty else { return }
        map.removeGeoJSONSourceFeatures(forSourceId: id, featureIds: Array(published))
        published = []
    }

    /// After a style reload the source starts empty again.
    func reset() { published = [] }
}
