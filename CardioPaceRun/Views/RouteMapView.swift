import SwiftUI
import MapKit

struct RouteMapView: UIViewRepresentable {
    let routePoints: [CoordinatePoint]
    let followUser: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = followUser
        mapView.showsCompass = true
        mapView.isRotateEnabled = false
        if followUser {
            mapView.userTrackingMode = .follow
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.showsUserLocation = followUser

        let coordinates = routePoints.map { $0.clCoordinate }
        let existingOverlays = mapView.overlays
        mapView.removeOverlays(existingOverlays)

        if coordinates.count >= 2 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)

            if !followUser, !context.coordinator.didFitStaticRoute {
                context.coordinator.didFitStaticRoute = true
                let rect = polyline.boundingMapRect
                let padding = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)
                mapView.setVisibleMapRect(rect, edgePadding: padding, animated: false)
            }
        } else if followUser, let last = coordinates.last {
            let region = MKCoordinateRegion(
                center: last,
                latitudinalMeters: 400,
                longitudinalMeters: 400
            )
            mapView.setRegion(region, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var didFitStaticRoute = false

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 4.5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
