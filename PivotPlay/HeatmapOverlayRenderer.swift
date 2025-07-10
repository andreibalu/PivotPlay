
import MapKit

class HeatmapOverlayRenderer: MKOverlayRenderer {
    private var locations: [CLLocation]

    init(overlay: MKOverlay, locations: [CLLocation]) {
        self.locations = locations
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let locationsInRect = locations.filter { mapRect.contains(MKMapPoint($0.coordinate)) }
        
        guard !locationsInRect.isEmpty else { return }

        let alpha: CGFloat = 0.5
        let colors: [UIColor] = [.blue, .green, .yellow, .red]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace,
                                  colors: colors.map { $0.withAlphaComponent(alpha).cgColor } as CFArray,
                                  locations: [0.25, 0.5, 0.75, 1.0])!

        for location in locationsInRect {
            let point = self.point(for: MKMapPoint(location.coordinate))
            let radius = 20 * zoomScale
            let center = point
            context.drawRadialGradient(gradient,
                                       startCenter: center,
                                       startRadius: 0,
                                       endCenter: center,
                                       endRadius: radius,
                                       options: .drawsAfterEndLocation)
        }
    }
}
