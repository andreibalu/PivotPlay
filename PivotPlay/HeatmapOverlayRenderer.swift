
import MapKit

class HeatmapOverlayRenderer: MKOverlayRenderer {
    
    private var locations: [CLLocation]

    init(overlay: MKOverlay, locations: [CLLocation]) {
        self.locations = locations
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let rect = self.rect(for: mapRect)
        
        let heatmap = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
            .cropped(to: rect)
        
        let coloredHeatmap = locations.reduce(heatmap) { (heatmap, location) -> CIImage in
            let point = self.point(for: MKMapPoint(location.coordinate))
            
            // Adjust radius based on zoomScale for better visual representation
            let radius = 100 * (1 / zoomScale)

            let radialGradient = CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter": CIVector(x: point.x, y: point.y),
                "inputRadius0": radius * 0.5,
                "inputRadius1": radius,
                "inputColor0": CIColor(red: 0, green: 1, blue: 0, alpha: 0.3),
                "inputColor1": CIColor(red: 1, green: 0, blue: 0, alpha: 0)
            ])!

            return radialGradient.outputImage!.composited(over: heatmap)
        }
        
        let colorControls = CIFilter(name: "CIColorControls", parameters: [
            kCIInputImageKey: coloredHeatmap,
            kCIInputSaturationKey: 1.5,
            kCIInputBrightnessKey: 0.1,
            kCIInputContrastKey: 1.25
        ])!

        let blurred = colorControls.outputImage!.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 30])
        
        if let outputImage = CIContext().createCGImage(blurred, from: rect) {
            context.draw(outputImage, in: rect)
        }
    }
}
