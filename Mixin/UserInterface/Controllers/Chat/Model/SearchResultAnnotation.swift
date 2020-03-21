import MapKit
import MixinServices

class SearchResultAnnotation: NSObject, MKAnnotation {
    
    let location: Location
    
    @objc var coordinate: CLLocationCoordinate2D {
        location.coordinate
    }
    
    init(location: Location) {
        self.location = location
        super.init()
    }
    
}
