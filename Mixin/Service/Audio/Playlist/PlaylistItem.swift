import Foundation
import AVFoundation
import GRDB
import MixinServices

final class PlaylistItem {
    
    static let beginLoadingAssetNotification = Notification.Name("one.mixin.messenger.PlaylistItem.beginLoadingAsset")
    static let finishLoadingAssetNotification = Notification.Name("one.mixin.messenger.PlaylistItem.finishLoadingAsset")
    
    let id: String
    
    private(set) var metadata: Metadata
    private(set) var asset: AVURLAsset?
    private(set) var isLoadingAsset = false {
        didSet {
            if isLoadingAsset {
                notificationCenter.post(name: Self.beginLoadingAssetNotification, object: self)
            } else {
                notificationCenter.post(name: Self.finishLoadingAssetNotification, object: self)
            }
        }
    }
    
    private let notificationCenter = NotificationCenter.default
    private let maxNumberOfTriesToFetchMetadata = 3
    
    convenience init(message: MessageItem) {
        if let mediaURL = message.mediaUrl, message.mediaStatus == MediaStatus.DONE.rawValue || message.mediaStatus == MediaStatus.READ.rawValue {
            let url = AttachmentContainer.url(for: .files, filename: mediaURL)
            self.init(id: message.messageId,
                      asset: AVURLAsset(url: url),
                      filename: message.name ?? message.mediaUrl ?? "")
        } else {
            self.init(id: message.messageId,
                      asset: nil,
                      filename: message.name)
        }
    }
    
    convenience init?(urlString: String) {
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
        self.init(id: id,
                  asset: asset,
                  filename: url.lastPathComponent)
    }
    
    private init(id: String, asset: AVURLAsset?, filename: String?) {
        self.id = id
        self.asset = asset
        if let asset = asset {
            let areValuesLoaded = asset.statusOfValue(forKey: #keyPath(AVAsset.commonMetadata), error: nil) == .loaded
                && asset.statusOfValue(forKey: #keyPath(AVAsset.duration), error: nil) == .loaded
            if areValuesLoaded {
                self.metadata = Metadata(asset: asset, filename: filename)
            } else {
                self.metadata = Metadata(image: nil, title: filename, subtitle: nil, duration: .zero)
                loadCommonMetadata(from: asset, filename: filename, numberOfTries: 0)
            }
        } else {
            self.metadata = Metadata(image: nil, title: filename, subtitle: nil, duration: .zero)
        }
    }
    
    func downloadAttachment() {
        guard asset == nil && !isLoadingAsset else {
            return
        }
        isLoadingAsset = true
        let job = AttachmentDownloadJob(messageId: id)
        if ConcurrentJobQueue.shared.addJob(job: job) {
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
        isLoadingAsset = false
    }
    
    private func loadCommonMetadata(from asset: AVAsset, filename: String?, numberOfTries: UInt) {
        guard numberOfTries < maxNumberOfTriesToFetchMetadata else {
            return
        }
        let keys = [#keyPath(AVAsset.commonMetadata), #keyPath(AVAsset.duration)]
        asset.loadValuesAsynchronously(forKeys: keys) { [weak self] in
            let areValuesLoaded = keys.allSatisfy {
                asset.statusOfValue(forKey: $0, error: nil) == .loaded
            }
            let areValuesLoadingFailed = keys.allSatisfy {
                asset.statusOfValue(forKey: $0, error: nil) == .failed
            }
            if areValuesLoaded {
                let metadata = Metadata(asset: asset, filename: filename)
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    self.metadata = metadata
                    self.isLoadingAsset = false
                }
            } else if areValuesLoadingFailed {
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.loadCommonMetadata(from: asset, filename: filename, numberOfTries: numberOfTries + 1)
                }
            }
        }
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
            self.init(id: messageId,
                      asset: AVURLAsset(url: url),
                      filename: name ?? mediaURL)
        } else {
            self.init(id: messageId,
                      asset: nil,
                      filename: name)
        }
        let jobId = AttachmentDownloadJob.jobId(transcriptId: nil, messageId: messageId)
        if let job = ConcurrentJobQueue.shared.findJobById(jodId: jobId) as? AttachmentDownloadJob {
            notificationCenter.addObserver(self,
                                           selector: #selector(updateAsset(_:)),
                                           name: AttachmentDownloadJob.didFinishNotification,
                                           object: job)
            isLoadingAsset = true
        }
    }
    
}

extension PlaylistItem {
    
    struct Metadata {
        
        let image: UIImage?
        let title: String?
        let subtitle: String?
        let duration: CMTime
        
        init(image: UIImage?, title: String?, subtitle: String?, duration: CMTime) {
            self.image = image
            self.title = title
            self.subtitle = subtitle
            self.duration = duration
        }
        
        init(asset: AVAsset, filename: String?) {
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
            
            self.init(image: image,
                      title: title ?? filename,
                      subtitle: subtitle ?? R.string.localizable.playlist_unknown_artist(),
                      duration: asset.duration)
        }
        
    }
    
}
