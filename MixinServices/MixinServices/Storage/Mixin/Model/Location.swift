import Foundation
import CoreLocation
import MapKit

open class Location: NSObject, Codable {
    
    public typealias Degrees = Double
    public typealias FoursquareJson = [String: Any]
    
    private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case name
        case address
        case venueType = "venue_type"
    }
    
    public let latitude: Degrees
    public let longitude: Degrees
    public let name: String?
    public let address: String?
    public let venueType: String?
    
    public private(set) lazy var coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    
    public private(set) lazy var iconUrl: URL? = {
        if let venueType = venueType {
            return URL(string: "https://ss3.4sqi.net/img/categories_v2/\(venueType)_88.png")
        } else {
            return nil
        }
    }()
    
    public private(set) lazy var mapItem: MKMapItem = {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = name
        return item
    }()
    
    public override var debugDescription: String {
        "Location { latitude: \(latitude), longitude: \(longitude), name: \(name ?? "(null)"), address: \(address ?? "(null)"), venueType: \(venueType) }"
    }
    
    public init(latitude: Degrees, longitude: Degrees, name: String?, address: String?, venueType: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.address = address
        self.venueType = venueType
    }
    
    public convenience init?(json: FoursquareJson) {
        guard let name = json["name"] as? String else {
            return nil
        }
        guard let location = json["location"] as? FoursquareJson else {
            return nil
        }
        guard let latitude = location["lat"] as? Degrees, let longitude = location["lng"] as? Degrees else {
            return nil
        }
        guard let formattedAddress = location["formattedAddress"] as? [String], let address = formattedAddress.first else {
            return nil
        }
        guard let categoriesJson = json["categories"] as? [FoursquareJson] else {
            return nil
        }
        guard let category = categoriesJson.compactMap(Category.init).first(where: { $0.isPrimary }) else {
            return nil
        }
        self.init(latitude: latitude,
                  longitude: longitude,
                  name: name,
                  address: address,
                  venueType: category.venueType)
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

extension Location {
    
    private struct Category {
        
        let isPrimary: Bool
        let venueType: String?
        
        init?(json: FoursquareJson) {
            guard let isPrimary = json["primary"] as? Bool else {
                return nil
            }
            guard let id = json["id"] as? String else {
                return nil
            }
            self.isPrimary = isPrimary
            self.venueType = venueTypes[id]
        }
        
    }
    
}
