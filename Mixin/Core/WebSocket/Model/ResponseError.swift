import Foundation

struct ResponseError: Codable {

    let status: Int
    let code: Int
    var description: String

}

extension ResponseError {

    func toError() -> APIError {
        return APIError(code: code, status: status, description: description)
    }

}
