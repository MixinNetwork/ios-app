import MapKit

class UserPickedLocation: NSObject, MKAnnotation {
    
    @objc var coordinate: CLLocationCoordinate2D
    
    var address: String?
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
    
}
