import Foundation
import Alamofire
import CoreLocation
import MixinServices

enum FoursquareAPI {
    
    typealias Completion = (Result<[Location], Error>) -> Void
    
    static func search(coordinate: CLLocationCoordinate2D, radius: Int?, query: String?, completion: @escaping Completion) -> Request? {
        guard let clientId = MixinKeys.Foursquare.clientId, let clientSecret = MixinKeys.Foursquare.clientSecret else {
            completion(.failure(ExternalApiError.noApiKey))
            return nil
        }
        var components = URLComponents(string: "https://api.foursquare.com/v2/venues/search")!
        var queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "v", value: "20200310"),
        ]
        if let radius = radius {
            let item = URLQueryItem(name: "radius", value: "\(radius)")
            queryItems.append(item)
        }
        if let query = query {
            let item = URLQueryItem(name: "query", value: query)
            queryItems.append(item)
        }
        components.queryItems = queryItems
        return AF.request(components.url!).responseJSON { (response) in
            switch response.result {
            case .success(let json as Location.FoursquareJson):
                guard let locations = [Location](json: json) else {
                    completion(.failure(ExternalApiError.badResponse))
                    return
                }
                completion(.success(locations))
            case .failure(let error):
                completion(.failure(error))
            default:
                completion(.failure(ExternalApiError.badResponse))
            }
        }
    }
    
}
