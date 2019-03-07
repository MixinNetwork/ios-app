import UIKit
import GiphyCoreSDK

class GiphyViewController: StickersCollectionViewController {
    
    var urls = [GiphyImageURL]()
    
    private let footerReuseId = "footer"
    private let loadingIndicator = UIActivityIndicatorView(style: .whiteLarge)
    
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
        return urls.isEmpty
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(UINib(nibName: "GiphyPoweredFooterView", bundle: .main),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: footerReuseId)
        (collectionView.collectionViewLayout as? TilingCollectionViewFlowLayout)?.contentRatio = 4 / 3
        loadingIndicator.color = .gray
        loadingIndicator.backgroundColor = .white
        loadingIndicator.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        loadingIndicator.frame = view.bounds
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)
        let numberOfCells = StickerInputModelController.maxNumberOfRecentStickers - 1
        GiphyCore.shared.trending(limit: numberOfCells) { [weak self] (response, error) in
            guard let weakSelf = self, let data = response?.data, error == nil else {
                return
            }
            let urls = data.compactMap(GiphyImageURL.init)
            DispatchQueue.main.async {
                weakSelf.loadingIndicator.stopAnimating()
                weakSelf.urls = urls
                weakSelf.collectionView.reloadData()
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return urls.count + 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! AnimatedImageCollectionViewCell
        if indexPath.row == 0 {
            cell.imageView.contentMode = .center
            cell.imageView.image = UIImage(named: "ic_giphy_search")
        } else {
            cell.imageView.contentMode = .scaleAspectFill
            let url = urls[indexPath.row - 1].preview
            cell.imageView.sd_setImage(with: url, completed: nil)
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            animated = false
            let vc = R.storyboard.chat.giphy_search()!
            vc.dataSource = dataSource
            present(vc, animated: true, completion: nil)
        } else {
            let url = urls[indexPath.row - 1].fullsized
            dataSource?.sendGif(at: url)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: footerReuseId, for: indexPath)
    }
    
}

extension GiphyViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return urls.isEmpty ? .zero : CGSize(width: collectionView.bounds.width, height: 60)
    }
    
}
