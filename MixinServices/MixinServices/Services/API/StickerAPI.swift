import Foundation
import Alamofire

public class StickerAPI : MixinAPI {
    
    public static let shared = StickerAPI()
    
    private enum url {
        static let albums = "stickers/albums"
        static func albums(id: String) -> String {
            return "stickers/albums/\(id)"
        }
        
        static let add = "stickers/favorite/add"
        static let remove = "stickers/favorite/remove"
        static func stickers(id: String) -> String {
            return "stickers/\(id)"
        }
    }
    
    public func albums()  -> MixinAPI.Result<[Album]> {
        return request(method: .get, url: url.albums)
    }

    public func albums(completion: @escaping (MixinAPI.Result<[Album]>) -> Void) {
        request(method: .get, url: url.albums, completion: completion)
    }
    
    public func stickers(albumId: String, completion: @escaping (MixinAPI.Result<[StickerResponse]>) -> Void) {
        request(method: .get, url: url.albums(id: albumId), completion: completion)
    }
    
    public func addSticker(stickerBase64: String, completion: @escaping (MixinAPI.Result<StickerResponse>) -> Void) {
        request(method: .post, url: url.add, parameters: ["data_base64": stickerBase64], completion: completion)
    }
    
    public func addSticker(stickerId: String, completion: @escaping (MixinAPI.Result<StickerResponse>) -> Void) {
        request(method: .post, url: url.add, parameters: ["sticker_id": stickerId], completion: completion)
    }
    
    public func sticker(stickerId: String) -> MixinAPI.Result<StickerResponse> {
        return request(method: .get, url: url.stickers(id: stickerId))
    }
    
    public func removeSticker(stickerIds: [String], completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, url: url.remove, parameters: stickerIds.toParameters(), encoding: JSONArrayEncoding(), completion: completion)
    }
    
}
