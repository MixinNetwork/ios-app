import Foundation
import MixinServices

extension Array where Element == FoursquareLocation {
    
    init?(json: FoursquareLocation.Json) {
        guard let meta = json["meta"] as? FoursquareLocation.Json else {
            return nil
        }
        guard let code = meta["code"] as? Int, code == 200 else {
            return nil
        }
        guard let response = json["response"] as? FoursquareLocation.Json else {
            return nil
        }
        guard let venues = response["venues"] as? [FoursquareLocation.Json] else {
            return nil
        }
        self = venues.compactMap(FoursquareLocation.init)
    }
    
}

class FoursquareLocation: Location {
    
    typealias Json = [String: Any]
    
    struct Category {
        
        let iconUrl: URL
        let isPrimary: Bool
        
        init?(json: Json) {
            guard let isPrimary = json["primary"] as? Bool else {
                return nil
            }
            guard let icon = json["icon"] as? Json else {
                return nil
            }
            guard let iconPrefix = icon["prefix"] as? String, let iconSuffix = icon["suffix"] as? String else {
                return nil
            }
            // https://developer.foursquare.com/docs/api/venues/categories
            let iconUrlString = iconPrefix + "88" + iconSuffix
            guard let iconUrl = URL(string: iconUrlString) else {
                return nil
            }
            self.iconUrl = iconUrl
            self.isPrimary = isPrimary
        }
        
    }
    
    private enum CodingKeys: String, CodingKey {
        case iconUrl = "icon_url"
    }
    
    let iconUrl: URL
    
    required init?(json: Json) {
        guard let name = json["name"] as? String else {
            return nil
        }
        guard let location = json["location"] as? Json else {
            return nil
        }
        guard let latitude = location["lat"] as? Degrees, let longitude = location["lng"] as? Degrees else {
            return nil
        }
        guard let formattedAddress = location["formattedAddress"] as? [String], let address = formattedAddress.first else {
            return nil
        }
        guard let categoriesJson = json["categories"] as? [Json] else {
            return nil
        }
        guard let category = categoriesJson.compactMap(Category.init).first(where: { $0.isPrimary }) else {
            return nil
        }
        self.iconUrl = category.iconUrl
        super.init(latitude: latitude, longitude: longitude, name: name, address: address)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        iconUrl = try container.decode(URL.self, forKey: .iconUrl)
        try super.init(from: container.superDecoder())
    }
    
}
