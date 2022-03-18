import MixinServices
import Alamofire

enum GiphyAPI {
    
    typealias Result = Swift.Result<[GiphyImage], Error>
    typealias Completion = (Result) -> Void
    
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
    
    static func trending(offset: Int = 0, limit: Int, completion: @escaping Completion) -> DataRequest? {
        guard let key = apiKey else {
            completion(.failure(ExternalApiError.noApiKey))
            return nil
        }
        let url = URL(string: "https://api.giphy.com/v1/gifs/trending?offset=\(offset)&limit=\(limit)&rating=r&api_key=\(key)")!
        let handler = GiphyAPI.handler(completion: completion)
        return AF.request(url).responseData(queue: .global(), completionHandler: handler)
    }
    
    static func search(keyword: String, offset: Int = 0, limit: Int, completion: @escaping Completion) -> DataRequest? {
        guard let key = apiKey else {
            completion(.failure(ExternalApiError.noApiKey))
            return nil
        }
        guard let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.success([]))
            return nil
        }
        let url = URL(string: "https://api.giphy.com/v1/gifs/search?q=\(encodedKeyword)&offset=\(offset)&limit=\(limit)&rating=r&lang=\(language)&api_key=\(key)")!
        let handler = GiphyAPI.handler(completion: completion)
        return AF.request(url).responseData(queue: .global(), completionHandler: handler)
    }
    
    static func handler(completion: @escaping Completion) -> (AFDataResponse<Data>) -> Void {
        { (response) in
            let result: Result
            switch response.result {
            case .success(let data):
                let json = try? JSONSerialization.jsonObject(with: data)
                if let json = json as? [String: Any], let data = json["data"] as? [[String: Any]] {
                    let images = data.compactMap(GiphyImage.init)
                    result = .success(images)
                } else {
                    result = .failure(ExternalApiError.badResponse)
                }
            case .failure(let error):
                result = .failure(error)
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
}
