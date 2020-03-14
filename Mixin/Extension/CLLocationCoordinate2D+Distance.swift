import CoreLocation

extension CLLocationCoordinate2D {
    
    func distance(from: CLLocationCoordinate2D) -> CLLocationDistance {
        let this = CLLocation(latitude: latitude, longitude: longitude)
        let that = CLLocation(latitude: from.latitude, longitude: from.longitude)
        return this.distance(from: that)
    }
    
}
