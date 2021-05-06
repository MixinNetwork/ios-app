import UIKit
import Alamofire

class GiphyViewController: StickersCollectionViewController, ConversationInputAccessible {
    
    var images = [GiphyImage]()
    
    private let footerReuseId = "footer"
    private let loadingIndicator = ActivityIndicatorView()
    
    private var request: DataRequest?
    
    init(index: Int) {
        super.init(nibName: nil, bundle: nil)
        self.index = index
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override var layoutClass: TilingCollectionViewFlowLayout.Type {
        return GiphyCollectionViewFlowLayout.self
    }
    
    override var isEmpty: Bool {
        return images.isEmpty
    }
    
    deinit {
        request?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(UINib(nibName: "GiphyPoweredFooterView", bundle: .main),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: footerReuseId)
        (collectionView.collectionViewLayout as? TilingCollectionViewFlowLayout)?.contentRatio = 4 / 3
        loadingIndicator.usesLargerStyle = true
        loadingIndicator.tintColor = .accessoryText
        loadingIndicator.backgroundColor = .background
        loadingIndicator.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        loadingIndicator.frame = view.bounds
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)
        let numberOfCells = StickerInputModelController.maxNumberOfRecentStickers - 1
        request = GiphyAPI.trending(limit: numberOfCells) { [weak self] (result) in
            guard case let .success(images) = result, let self = self else {
                return
            }
            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating()
                self.images = images
                self.collectionView.reloadData()
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count + 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! StickerPreviewCell
        if indexPath.row == 0 {
            cell.stickerView.load(image: R.image.ic_giphy_search(), contentMode: .center)
        } else {
            let url = images[indexPath.row - 1].previewUrl
            cell.stickerView.load(imageURL: url, contentMode: .scaleAspectFill)
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            animated = false
            let vc = R.storyboard.chat.giphy_search()!
            vc.composer = composer
            vc.onDisappear = { [weak self] in
                self?.animated = true
            }
            present(vc, animated: true, completion: nil)
        } else {
            let image = images[indexPath.row - 1]
            let cell = collectionView.cellForItem(at: indexPath) as? StickerPreviewCell
            composer?.send(image: image, thumbnail: cell?.image)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: footerReuseId, for: indexPath)
    }
    
}

extension GiphyViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return images.isEmpty ? .zero : CGSize(width: collectionView.bounds.width, height: 60)
    }
    
}
