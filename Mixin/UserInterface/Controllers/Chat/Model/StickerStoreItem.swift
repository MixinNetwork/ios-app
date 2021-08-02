import Foundation
import MixinServices

struct StickerStoreItem {
    
    let album: Album
    let stickers: [StickerItem]
    var isAdded: Bool = false
    
}
