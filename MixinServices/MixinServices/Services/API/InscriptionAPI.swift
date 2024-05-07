import Foundation
import Alamofire

public final class InscriptionAPI: MixinAPI {
    
    private enum Path {
        
        static func collection(collectionHash: String) -> String {
            "/safe/inscriptions/collections/\(collectionHash)"
        }
        
        static func inscription(inscriptionHash: String) -> String {
            "/safe/inscriptions/items/\(inscriptionHash)"
        }
        
    }
    
    public static func inscription(inscriptionHash: String) -> MixinAPI.Result<Inscription> {
        return request(method: .get, path: Path.inscription(inscriptionHash: inscriptionHash))
    }
    
    public static func inscription(inscriptionHash: String) async throws -> Inscription {
        try await request(method: .get, path: Path.inscription(inscriptionHash: inscriptionHash))
    }
    
    public static func collection(collectionHash: String) -> MixinAPI.Result<InscriptionCollection> {
        return request(method: .get, path: Path.collection(collectionHash: collectionHash))
    }
    
    public static func collection(collectionHash: String) async throws -> InscriptionCollection {
        try await request(method: .get, path: Path.collection(collectionHash: collectionHash))
    }
    
}
