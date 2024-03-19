import Foundation
import Alamofire

public final class TIPAPI: MixinAPI {
    
    static func ephemerals() async throws -> [TIPEphemeral] {
        try await withCheckedThrowingContinuation { continuation in
            request(method: .get, path: "/tip/ephemerals") { result in
                continuation.resume(with: result)
            }
        }
    }
    
    static func updateEphemeral(base64URLEncoded ephemeral: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Empty, Error>) in
            let parameters = [
                "device_id": Device.current.id,
                "seed_base64": ephemeral
            ]
            request(method: .post, path: "/tip/ephemerals", parameters: parameters) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    static func identity() async throws -> TIPIdentity {
        try await withCheckedThrowingContinuation { continuation in
            request(method: .get, path: "/tip/identity") { result in
                continuation.resume(with: result)
            }
        }
    }
    
    static func readSecret(request: TIPSecretReadRequest) async throws -> TIPSecretReadResponse {
        try await withCheckedThrowingContinuation { continuation in
            self.request(method: .post, path: "/tip/secret", parameters: request) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    static func updateSecret(request: TIPSecretUpdateRequest) async throws -> Empty {
        try await withCheckedThrowingContinuation { continuation in
            self.request(method: .post, path: "/tip/secret", parameters: request) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    static func sign(url: URL, request: TIPSignRequest) async throws -> TIPSignResponse {
        try await AF.request(url, method: .post, parameters: request, encoder: .json, headers: ["X-Request-Id": request.id])
            .validate(statusCode: 200...299)
            .serializingDecodable(TIPSignResponse.self)
            .value
    }
    
    static func watch(url: URL, request: TIPWatchRequest, timeoutInterval: TimeInterval) async throws -> TIPWatchResponse {
        try await AF.request(url, method: .post, parameters: request, encoder: .json, requestModifier: { $0.timeoutInterval = timeoutInterval })
            .validate(statusCode: 200...299)
            .serializingDecodable(TIPWatchResponse.self)
            .value
    }
    
    public static func tipGas(id: String, completion: @escaping (MixinAPI.Result<TIPGas>) -> Void) {
        request(method: .get, path: "/external/gastracker/\(id)", queue: .global(), completion: completion)
    }
    
}
