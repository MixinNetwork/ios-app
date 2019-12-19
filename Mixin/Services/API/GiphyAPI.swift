import Foundation
import Alamofire

public enum GiphyAPI {
    
    public enum Error: Swift.Error {
        case noApiKey
        case badResponse
    }
    
    public typealias Completion = (Result<[GiphyImage]>) -> Void
    
    private static var apiKey = MixinKeys.giphy
    private static var language: String {
        guard let language = Locale.current.languageCode else {
            return "en"
        }
        if language == "zh", let regionCode = Locale.current.regionCode {
            return language + "-" + regionCode
        } else {
            return language
        }
    }
    
    public static func trending(offset: Int = 0, limit: Int, completion: @escaping Completion) -> DataRequest? {
        guard let key = apiKey else {
            completion(.failure(Error.noApiKey))
            return nil
        }
        let url = URL(string: "https://api.giphy.com/v1/gifs/trending?offset=\(offset)&limit=\(limit)&rating=r&api_key=\(key)")!
        let handler = GiphyAPI.handler(completion: completion)
        return request(url).responseJSON(completionHandler: handler)
    }
    
    public static func search(keyword: String, offset: Int = 0, limit: Int, completion: @escaping Completion) -> DataRequest? {
        guard let key = apiKey else {
            completion(.failure(Error.noApiKey))
            return nil
        }
        guard let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.success([]))
            return nil
        }
        let url = URL(string: "https://api.giphy.com/v1/gifs/search?q=\(encodedKeyword)&offset=\(offset)&limit=\(limit)&rating=r&lang=\(language)&api_key=\(key)")!
        let handler = GiphyAPI.handler(completion: completion)
        return request(url).responseJSON(completionHandler: handler)
    }
    
    static func handler(completion: @escaping Completion) -> (DataResponse<Any>) -> Void {
        return { (response) in
            switch response.result {
            case .success(let json):
                guard let json = json as? [String: Any] else {
                    completion(.failure(Error.badResponse))
                    return
                }
                guard let data = json["data"] as? [[String: Any]] else {
                    completion(.failure(Error.badResponse))
                    return
                }
                let images = data.compactMap(GiphyImage.init)
                completion(.success(images))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
}
