import Foundation
import SDWebImage

class RefreshStickerJob: BaseJob {

    private let albumId: String?

    init(albumId: String? = nil) {
        self.albumId = albumId
    }

    override func getJobId() -> String {
        guard let albumId = self.albumId else {
            return "refresh-sticker"
        }
        return "refresh-sticker-\(albumId)"
    }

    override func run() throws {
        if let albumId = self.albumId {
            try RefreshStickerJob.cacheStickers(albumId: albumId)
        } else {
            let stickerAlbums = AlbumDAO.shared.getAblumsUpdateAt()
            switch StickerAPI.shared.albums() {
            case let .success(albums):
                for album in albums {
                    guard stickerAlbums[album.albumId] != album.updateAt else {
                        continue
                    }
                    RefreshStickerJob.cacheImage(album.iconUrl)
                    try RefreshStickerJob.cacheStickers(albumId: album.albumId)
                    AlbumDAO.shared.insertOrUpdateAblum(album: album)
                }

                if !DatabaseUserDefault.shared.upgradeStickers {
                    MessageDAO.shared.updateOldStickerMessages()
                    DatabaseUserDefault.shared.upgradeStickers = true
                }
            case let .failure(error):
                throw error
            }
        }
    }

    static func cacheStickers(albumId: String) throws {
        switch StickerAPI.shared.stickers(albumId: albumId) {
        case let .success(stickers):
            StickerDAO.shared.insertOrUpdateStickers(stickers: stickers)
            for sticker in stickers {
                cacheImage(sticker.assetUrl)
            }
            StickerAlbumDAO.shared.inserOrUpdate(albumId: albumId, stickers: stickers)
        case let .failure(error):
            throw error
        }
    }

    private static func cacheImage(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        SDWebImageManager.shared().loadImage(with:url, options: [.continueInBackground, .retryFailed, .refreshCached], progress: nil) { (_, _, _, _, _, _) in

        }
    }
}

