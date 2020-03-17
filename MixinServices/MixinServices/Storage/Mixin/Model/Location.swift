import Foundation
import CoreLocation
import MapKit

open class Location: NSObject, Codable {
    
    public typealias Degrees = Double
    public typealias FoursquareJson = [String: Any]
    
    public let latitude: Degrees
    public let longitude: Degrees
    public let name: String?
    public let address: String?
    public let venueType: String?
    
    public private(set) lazy var wgs84Coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    
    public private(set) lazy var gcj02CompatibleCoordinate: CLLocationCoordinate2D = {
        let converted = Self.gcj02Coordinate(wgs84Coordinate: wgs84Coordinate)
        if Self.isCoordinateCoveredByGcj02(converted) {
            return converted
        } else {
            return wgs84Coordinate
        }
    }()
    
    public private(set) lazy var iconUrl: URL? = {
        if let venueType = venueType {
            return URL(string: "https://ss3.4sqi.net/img/categories_v2/\(venueType)_88.png")
        } else {
            return nil
        }
    }()
    
    public private(set) lazy var mapItem: MKMapItem = {
        let placemark = MKPlacemark(coordinate: gcj02CompatibleCoordinate)
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
    
    public var coordinate: CLLocationCoordinate2D {
        gcj02CompatibleCoordinate
    }
    
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
    
    private static let gcj02AreaCoordinates: [(latitude: Degrees, longitude: Degrees)] = {
        let url = Bundle.mixinServicesResource.url(forResource: "GCJ02", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        let points = try! JSONSerialization.jsonObject(with: data, options: []) as! [[Degrees]]
        return points.map({ ($0[0], $0[1] )})
    }()
    
    private static func isCoordinateCoveredByGcj02(_ coordinate: CLLocationCoordinate2D) -> Bool {
        var isCovered = false
        for index in 0..<gcj02AreaCoordinates.count {
            let nextIndex = (index + 1) == gcj02AreaCoordinates.count ? 0 : index + 1
            let edgePoint = gcj02AreaCoordinates[index]
            let nextPoint = gcj02AreaCoordinates[nextIndex]
            
            let pointX = edgePoint.longitude
            let pointY = edgePoint.latitude
            
            let nextPointX = nextPoint.longitude
            let nextPointY = nextPoint.latitude
            
            if (coordinate.longitude == pointX && coordinate.latitude == pointY) || (coordinate.longitude == nextPointX && coordinate.latitude == nextPointY)  {
                isCovered = true
            }
            if((nextPointY < coordinate.latitude && pointY >= coordinate.latitude) || (nextPointY >= coordinate.latitude && pointY < coordinate.latitude)) {
                let thX = nextPointX + (coordinate.latitude - nextPointY) * (pointX - nextPointX) / (pointY - nextPointY)
                if(thX == coordinate.longitude) {
                    isCovered = true
                    break
                }
                if(thX > coordinate.longitude) {
                    isCovered = !isCovered
                }
            }
        }
        return isCovered
    }
    
    private static func gcj02Coordinate(wgs84Coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let a = 6378245.0
        let ee = 0.00669342162296594323
        let x = wgs84Coordinate.longitude - 105.0
        let y = wgs84Coordinate.latitude - 35.0
        let latitude = (-100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(fabs(x)))
            + ((20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0)
            + ((20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0)
            + ((160.0 * sin(y / 12.0 * .pi) + 320 * sin(y * .pi / 30.0)) * 2.0 / 3.0)
        let longitude = (300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(fabs(x)))
            + ((20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0)
            + ((20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0)
            + ((150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0)
        let radLat = 1 - wgs84Coordinate.latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        let dx = (latitude * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        let dy = (longitude * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        return CLLocationCoordinate2D(latitude: wgs84Coordinate.latitude + dx,
                                      longitude: wgs84Coordinate.longitude + dx)
    }
    
}
