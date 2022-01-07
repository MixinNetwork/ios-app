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
