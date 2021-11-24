import Foundation
import SDWebImage

public class RefreshStickerCacheJob: AsynchronousJob {
    
    public enum Operation {
        case add(stickers: [StickerItem], albumId: String)
        case remove(stickers: [StickerItem], albumId: String)
    }
    
    private let operation: Operation
    
    public init(_ operation: Operation) {
        self.operation = operation
    }
    
    override public func getJobId() -> String {
        switch operation {
        case .add(_, let albumId):
            return "refresh-stickers-cache-add-\(albumId)"
        case .remove(_, let albumId):
            return "refresh-stickers-cache-remove-\(albumId)"
        }
    }
    
    public override func execute() -> Bool {
        switch operation {
        case let .add(stickers, albumId):
            let dstPath = SDImageCache.persistentSticker.diskCachePath
            var prefetchStickers = [StickerItem]()
            for sticker in stickers {
                let url = sticker.assetUrl
                if let data = SDImageCache.shared.diskImageData(forKey: url) {
                    SDImageCache.persistentSticker.storeImageData(toDisk: data, forKey: url)
                    SDImageCache.shared.removeImageFromDisk(forKey: url)
                } else {
                    prefetchStickers.append(sticker)
                }
            }
            if !prefetchStickers.isEmpty {
                StickerPrefetcher.prefetch(stickers: prefetchStickers, albumId: albumId)
            }
        case let .remove(stickers, albumId):
            StickerPrefetcher.cancelPrefetching(albumId: albumId)
            let dstPath = SDImageCache.shared.diskCachePath
            for sticker in stickers {
                let url = sticker.assetUrl
                if !SDImageCache.shared.diskImageDataExists(withKey: url), let data = SDImageCache.persistentSticker.diskImageData(forKey: url) {
                    SDImageCache.shared.storeImageData(toDisk: data, forKey: url)
                }
                SDImageCache.persistentSticker.removeImageFromDisk(forKey: url)
            }
        }
        finishJob()
        return true
    }
    
}
