import Foundation

enum TIPSignResponse: Decodable {
    
    struct Success: Decodable {
        
        struct SignData: Codable {
            let cipher: String
        }
        
        let data: SignData
        let signature: String
        
    }
    
    struct Failure: Decodable {
        
        struct Error: Swift.Error, Decodable {
            
            let code: Int
            
            var isFatal: Bool {
                [403, 429, 500].contains(code)
            }
            
        }
        
        let error: Error
        
    }
    
    case success(Success)
    case failure(Failure)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self = .success(try container.decode(Success.self))
        } catch let rawError {
            do {
                self = .failure(try container.decode(Failure.self))
            } catch {
                throw rawError
            }
        }
    }
    
}
