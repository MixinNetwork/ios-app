import UIKit
import GiphyCoreSDK
import SDWebImage
import YYImage

class GiphyViewController: StickersCollectionViewController {
    
    var urls = [URL]()
    
    init(index: Int) {
        super.init(nibName: nil, bundle: nil)
        self.index = index
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override var isEmpty: Bool {
        return urls.isEmpty
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        GiphyCore.shared.trending(limit: StickerInputModelController.maxNumberOfRecentStickers) { [weak self] (response, error) in
            guard let weakSelf = self, let data = response?.data, error == nil else {
                return
            }
            let urls = data.compactMap(weakSelf.urlFromGPHMedia)
            DispatchQueue.main.async {
                weakSelf.urls = urls
                weakSelf.collectionView.reloadData()
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return urls.count + 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! StickerCollectionViewCell
        if indexPath.row == 0 {
            cell.imageView.image = UIImage(named: "ic_giphy_search")
        } else {
            cell.imageView.sd_setImage(with: urls[indexPath.row - 1], completed: nil)
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            conversationViewController?.presentGiphySearch()
        } else {
            sendImage(at: indexPath.row - 1)
        }
    }
    
    private func urlFromGPHMedia(_ media: GPHMedia?) -> URL? {
        guard let str = media?.images?.fixedWidth?.gifUrl else {
            return nil
        }
        return URL(string: str)
    }
    
    private func sendImage(at index: Int) {
        guard let dataSource = conversationViewController?.dataSource else {
            return
        }
        let url = urls[index]
        var message = Message.createMessage(category: MessageCategory.SIGNAL_IMAGE.rawValue,
                                            conversationId: dataSource.conversationId,
                                            userId: AccountAPI.shared.accountUserId)
        message.mediaStatus = MediaStatus.PENDING.rawValue
        SDWebImageManager.shared.loadImage(with: url, options: .highPriority, progress: nil) { (image, _, _, _, _, _) in
            guard let image = image as? YYImage, let data = image.animatedImageData else {
                return
            }
            DispatchQueue.global().async {
                let filename = message.messageId + ExtensionName.gif.withDot
                let targetUrl = MixinFile.url(ofChatDirectory: .photos, filename: filename)
                do {
                    try data.write(to: targetUrl)
                    if FileManager.default.fileSize(targetUrl.path) > 0 {
                        message.thumbImage = image.base64Thumbnail()
                        message.mediaSize = FileManager.default.fileSize(targetUrl.path)
                        message.mediaWidth = Int(image.size.width)
                        message.mediaHeight = Int(image.size.height)
                        message.mediaMimeType = "image/jpeg"
                        message.mediaUrl = filename
                    }
                } catch {
                    
                }
                SendMessageService.shared.sendMessage(message: message,
                                                      ownerUser: dataSource.ownerUser,
                                                      isGroupMessage: dataSource.category == .group)
            }
        }
    }
    
}
