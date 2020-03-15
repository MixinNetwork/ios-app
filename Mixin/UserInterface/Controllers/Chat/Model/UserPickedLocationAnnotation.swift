import MapKit

class UserPickedLocationAnnotation: NSObject, MKAnnotation {
    
    @objc var coordinate: CLLocationCoordinate2D
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
    
}
