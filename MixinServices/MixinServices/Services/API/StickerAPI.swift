import Foundation
import Alamofire

public final class StickerAPI : MixinAPI {
    
    private enum Path {
        static let albums = "/stickers/albums"
        static func albums(id: String) -> String {
            "/stickers/albums/\(id)"
        }
        static func album(id: String) -> String {
            "/albums/\(id)"
        }
        static let add = "/stickers/favorite/add"
        static let remove = "/stickers/favorite/remove"
        static func stickers(id: String) -> String {
            "/stickers/\(id)"
        }
    }
    
    public static func albums() -> MixinAPI.Result<[Album]> {
        return request(method: .get, path: Path.albums)
    }
    
    public static func albums(completion: @escaping (MixinAPI.Result<[Album]>) -> Void) {
        request(method: .get, path: Path.albums, completion: completion)
    }
    
    public static func album(albumId: String) -> MixinAPI.Result<Album> {
        return request(method: .get, path: Path.album(id: albumId))
    }
    
    public static func stickers(albumId: String, completion: @escaping (MixinAPI.Result<[StickerResponse]>) -> Void) {
        request(method: .get, path: Path.albums(id: albumId), completion: completion)
    }
    
    public static func stickers(albumId: String) -> MixinAPI.Result<[StickerResponse]> {
        request(method: .get, path: Path.albums(id: albumId))
    }
    
    public static func addSticker(base64EncodedImage data: String, completion: @escaping (MixinAPI.Result<StickerResponse>) -> Void) {
        request(method: .post, path: Path.add, parameters: ["data_base64": data], completion: completion)
    }
    
    public static func addSticker(stickerId: String, completion: @escaping (MixinAPI.Result<StickerResponse>) -> Void) {
        request(method: .post, path: Path.add, parameters: ["sticker_id": stickerId], completion: completion)
    }
    
    public static func sticker(stickerId: String) -> MixinAPI.Result<StickerResponse> {
        return request(method: .get, path: Path.stickers(id: stickerId))
    }
    
    public static func sticker(stickerId: String, completion: @escaping (MixinAPI.Result<StickerResponse>) -> Void) {
        request(method: .get, path: Path.stickers(id: stickerId), completion: completion)
    }
    
    public static func removeSticker(stickerIds: [String], completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, path: Path.remove, parameters: stickerIds, completion: completion)
    }
    
}
