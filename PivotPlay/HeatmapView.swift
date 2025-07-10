
import SwiftUI
import MapKit
import CoreLocation

struct HeatmapView: UIViewRepresentable {
    var locations: [CLLocation]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybrid
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        let overlay = HeatmapOverlay(locations: locations)
        uiView.addOverlay(overlay)

        if let firstLocation = locations.first {
            let region = MKCoordinateRegion(center: firstLocation.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            uiView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: HeatmapView

        init(_ parent: HeatmapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is HeatmapOverlay {
                return HeatmapOverlayRenderer(overlay: overlay, locations: parent.locations)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
