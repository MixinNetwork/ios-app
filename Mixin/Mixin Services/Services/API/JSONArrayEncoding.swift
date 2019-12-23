import Foundation
import Alamofire

fileprivate let jsonContentKey = "jsonArray"

public extension Array {
    
    func toParameters() -> Parameters {
        return [jsonContentKey: self]
    }
    
}

public extension Encodable {

    func toParameters() -> Parameters {
        return [jsonContentKey: self]
    }

}

public struct JSONArrayEncoding: ParameterEncoding {
    
    public let options: JSONSerialization.WritingOptions
    
    public init(options: JSONSerialization.WritingOptions = []) {
        self.options = options
    }
    
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        guard let parameters = parameters, let array = parameters[jsonContentKey] else { return urlRequest }
        do {
            let data = try JSONSerialization.data(withJSONObject: array, options: options)
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            urlRequest.httpBody = data
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
        return urlRequest
    }
    
}

public struct EncodableParameterEncoding<T: Encodable>: ParameterEncoding {
    
    public init() {
        
    }
    
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        guard let parameters = parameters, let encodable = parameters[jsonContentKey] as? T else {
            return urlRequest
        }
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            let data = try JSONEncoder().encode(encodable)
            urlRequest.httpBody = data
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
        return urlRequest
    }
    
}
