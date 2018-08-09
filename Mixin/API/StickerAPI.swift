import Foundation
import Alamofire

class StickerAPI : BaseAPI {
    static let shared = StickerAPI()
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

    func albums()  -> APIResult<[Album]> {
        return request(method: .get, url: url.albums)
    }

    func stickers(albumId: String) -> APIResult<[StickerResponse]> {
        return request(method: .get, url: url.albums(id: albumId))
    }

    func addSticker(stickerBase64: String, completion: @escaping (APIResult<StickerResponse>) -> Void) {
        request(method: .post, url: url.add, parameters: ["data_base64": stickerBase64], completion: completion)
    }

    func addSticker(stickerId: String, completion: @escaping (APIResult<StickerResponse>) -> Void) {
        request(method: .post, url: url.add, parameters: ["sticker_id": stickerId], completion: completion)
    }

    func sticker(stickerId: String) -> APIResult<StickerResponse> {
        return request(method: .get, url: url.stickers(id: stickerId))
    }

    func removeSticker(stickerIds: [String], completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: url.remove, parameters: stickerIds.toParameters(), encoding: JSONArrayEncoding(), completion: completion)
    }
}
