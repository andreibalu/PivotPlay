
import MapKit

class HeatmapOverlay: NSObject, MKOverlay {
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    let locations: [CLLocation]

    init(locations: [CLLocation]) {
        self.locations = locations
        self.coordinate = .init(latitude: 0, longitude: 0)

        // Create a bounding box that contains all locations.
        var boundingBox = MKMapRect.null
        locations.forEach { location in
            let point = MKMapPoint(location.coordinate)
            let rect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            boundingBox = boundingBox.union(rect)
        }
        self.boundingMapRect = boundingBox
    }
}
