import Foundation
import CoreLocation

public class Location: Codable {
    
    public typealias Degrees = Double
    
    public let latitude: Degrees
    public let longitude: Degrees
    public let name: String?
    public let address: String?
    
    public private(set) lazy var coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    
    public init(latitude: Degrees, longitude: Degrees, name: String?, address: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.address = address
    }
    
}

extension Location: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        "Location { latitude: \(latitude), longitude: \(longitude), name: \(name ?? "(null)"), address: \(address ?? "(null)") }"
    }
    
}
