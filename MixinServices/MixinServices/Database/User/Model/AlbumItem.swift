import Foundation
import GRDB

public struct AlbumItem {
    
    public let album: Album
    public let stickers: [StickerItem]
    public var isAdded: Bool
    
    public init(album: Album, stickers: [StickerItem]) {
        self.album = album
        self.stickers = stickers
        self.isAdded = album.isAdded
    }
    
}

extension AlbumItem: Codable, DatabaseColumnConvertible, MixinFetchableRecord {

    public enum CodingKeys: String, CodingKey {
        case album
        case stickers
        case isAdded = "added"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        album = try container.decode(Album.self, forKey: .album)
        stickers = try container.decodeIfPresent([StickerItem].self, forKey: .stickers) ?? []
        isAdded = try container.decodeIfPresent(Bool.self, forKey: .isAdded) ?? false
    }
    
}
