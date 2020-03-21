import Foundation

extension Array where Element == Location {
    
    public init?(json: Location.FoursquareJson) {
        guard let meta = json["meta"] as? Location.FoursquareJson else {
            return nil
        }
        guard let code = meta["code"] as? Int, code == 200 else {
            return nil
        }
        guard let response = json["response"] as? Location.FoursquareJson else {
            return nil
        }
        guard let venues = response["venues"] as? [Location.FoursquareJson] else {
            return nil
        }
        self = venues.compactMap(Location.init)
    }
    
}
