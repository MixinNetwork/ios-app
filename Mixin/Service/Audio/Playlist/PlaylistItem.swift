import Foundation
import AVFoundation
import GRDB
import MixinServices

final class PlaylistItem {
    
    static let willDownloadAssetNotification = Notification.Name("one.mixin.messenger.PlaylistItem.willDownloadAsset")
    static let didDownloadAssetNotification = Notification.Name("one.mixin.messenger.PlaylistItem.didDownloadAsset")
    
    let id: String
    
    private(set) var isDownloading = false
    private(set) var metadata: Metadata
    private(set) var asset: AVURLAsset?
    
    private let notificationCenter = NotificationCenter.default
    
    init(message: MessageItem) {
        self.id = message.messageId
        if let mediaURL = message.mediaUrl, message.mediaStatus == MediaStatus.DONE.rawValue || message.mediaStatus == MediaStatus.READ.rawValue {
            let url = AttachmentContainer.url(for: .files, filename: mediaURL)
            let asset = AVURLAsset(url: url)
            self.asset = asset
            let filename = message.name ?? message.mediaUrl ?? ""
            self.metadata = Metadata(asset: asset, filename: filename)
        } else {
            self.asset = nil
            self.metadata = Metadata(image: nil, title: message.name, subtitle: nil)
        }
    }
    
    init?(urlString: String) {
        guard let url = URL(string: urlString) else {
            return nil
        }
        guard let id = url.absoluteString.sha1 else {
            return nil
        }
        let asset: AVURLAsset
        if CacheableAsset.isURLCacheable(url) {
            asset = CacheableAsset(url: url)
        } else {
            asset = AVURLAsset(url: url)
        }
        self.id = id
        self.asset = asset
        self.metadata = Metadata(asset: asset, filename: url.lastPathComponent)
    }
    
    internal init(id: String, metadata: PlaylistItem.Metadata, asset: AVURLAsset?) {
        self.id = id
        self.metadata = metadata
        self.asset = asset
    }
    
    func downloadAttachment() {
        guard asset == nil && !isDownloading else {
            return
        }
        isDownloading = true
        let job = FileDownloadJob(messageId: id)
        if ConcurrentJobQueue.shared.addJob(job: job) {
            notificationCenter.post(name: Self.willDownloadAssetNotification,
                                    object: self)
            notificationCenter.addObserver(self,
                                           selector: #selector(updateAsset(_:)),
                                           name: AttachmentDownloadJob.didFinishNotification,
                                           object: job)
        }
    }
    
    @objc private func updateAsset(_ notification: Notification) {
        guard let filename = notification.userInfo?[AttachmentDownloadJob.UserInfoKey.mediaURL] as? String else {
            return
        }
        let url = AttachmentContainer.url(for: .files, filename: filename)
        let asset = AVURLAsset(url: url)
        self.metadata = Metadata(asset: asset, filename: url.lastPathComponent)
        self.asset = asset
        notificationCenter.removeObserver(self)
        notificationCenter.post(name: Self.didDownloadAssetNotification, object: self)
        isDownloading = false
    }
    
}

extension PlaylistItem: TableRecord {
    
    public static let databaseTableName = Message.databaseTableName
    
}

extension PlaylistItem: Decodable, DatabaseColumnConvertible, MixinFetchableRecord {
    
    enum CodingKeys: String, CodingKey {
        case messageId = "id"
        case conversationId = "conversation_id"
        case mediaURL = "media_url"
        case name
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let messageId = try container.decode(String.self, forKey: .messageId)
        let name = try container.decodeIfPresent(String.self, forKey: .name)
        if let mediaURL = try container.decodeIfPresent(String.self, forKey: .mediaURL), !mediaURL.isEmpty {
            let url = AttachmentContainer.url(for: .files, filename: mediaURL)
            let asset = AVURLAsset(url: url)
            let metadata = Metadata(asset: asset, filename: name ?? url.lastPathComponent)
            self.init(id: messageId, metadata: metadata, asset: asset)
        } else {
            let metadata = Metadata(image: nil, title: name, subtitle: nil)
            self.init(id: messageId, metadata: metadata, asset: nil)
        }
        let jobId = FileDownloadJob.jobId(messageId: messageId)
        if let job = ConcurrentJobQueue.shared.findJobById(jodId: jobId) as? FileDownloadJob {
            notificationCenter.addObserver(self,
                                           selector: #selector(updateAsset(_:)),
                                           name: AttachmentDownloadJob.didFinishNotification,
                                           object: job)
            isDownloading = true
        }
    }
    
}

extension PlaylistItem {
    
    final class Metadata {
        
        let image: UIImage?
        let title: String?
        let subtitle: String?
        
        init(image: UIImage?, title: String?, subtitle: String?) {
            self.image = image
            self.title = title
            self.subtitle = subtitle
        }
        
        init(asset: AVURLAsset, filename: String) {
            var image: UIImage?
            var title: String?
            var subtitle: String?
            for metadata in asset.commonMetadata {
                switch metadata.commonKey {
                case AVMetadataKey.commonKeyArtwork:
                    if let data = metadata.dataValue, let artwork = UIImage(data: data) {
                        image = artwork
                    }
                case AVMetadataKey.commonKeyTitle:
                    title = metadata.stringValue
                case AVMetadataKey.commonKeyArtist:
                    subtitle = metadata.stringValue
                default:
                    break
                }
            }
            self.image = image
            self.title = title ?? filename
            self.subtitle = subtitle ?? R.string.localizable.playlist_unknown_artist()
        }
        
    }
    
}
