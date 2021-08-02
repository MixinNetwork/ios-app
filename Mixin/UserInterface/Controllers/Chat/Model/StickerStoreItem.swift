import Foundation
import MixinServices

struct StickerStoreItem {
    
    let album: Album
    let stickers: [StickerItem]
    var isAdded: Bool = Bool.random()
    
}

extension StickerStoreItem {
    
    var albumId: String {
        return album.albumId
    }
    
}
