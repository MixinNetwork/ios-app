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
    
    static func sign(
        path: String,
        request: TIPSignRequest,
    ) async throws -> TIPSignResponse {
        try await withCheckedThrowingContinuation { continuation in
            self.request(
                method: .post,
                path: path,
                parameters: request,
                options: [.requestID(request.id), .timeoutInterval(15), .rawResponseObject],
            ) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    static func watch(
        path: String,
        request: TIPWatchRequest,
        timeoutInterval: TimeInterval,
    ) async throws -> TIPWatchResponse {
        try await withCheckedThrowingContinuation { continuation in
            self.request(
                method: .post,
                path: path,
                parameters: request,
                options: [.timeoutInterval(timeoutInterval), .rawResponseObject],
            ) { result in
                continuation.resume(with: result)
            }
        }
    }
    
}
