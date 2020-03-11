import Foundation
import CoreLocation
import MapKit

open class Location: NSObject, Codable {
    
    public typealias Degrees = Double
    
    public let latitude: Degrees
    public let longitude: Degrees
    public let name: String?
    public let address: String?
    
    public private(set) lazy var coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    public private(set) lazy var mapItem: MKMapItem = {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = name
        return item
    }()
    
    public override var debugDescription: String {
        "Location { latitude: \(latitude), longitude: \(longitude), name: \(name ?? "(null)"), address: \(address ?? "(null)") }"
    }
    
    public init(latitude: Degrees, longitude: Degrees, name: String?, address: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.address = address
    }
    
}

extension Location: MKAnnotation {
    
    public var title: String? {
        name
    }
    
    public var subtitle: String? {
        address
    }
    
}
