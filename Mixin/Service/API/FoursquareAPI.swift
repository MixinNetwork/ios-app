import Foundation
import Alamofire
import CoreLocation
import MixinServices

enum FoursquareAPI {
    
    typealias Result = Swift.Result<[Location], Error>
    typealias Completion = (Result) -> Void
    
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
        return AF.request(components.url!).responseData(queue: .global()) { response in
            let result: Result
            switch response.result {
            case .success(let data):
                let json = try? JSONSerialization.jsonObject(with: data)
                if let json = json as? Location.FoursquareJson, let locations = [Location](json: json) {
                    result = .success(locations)
                } else {
                    result = .failure(ExternalApiError.badResponse)
                }
            case .failure(let error):
                result = .failure(error)
            default:
                result = .failure(ExternalApiError.badResponse)
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
}
